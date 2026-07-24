BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Task dependencies are first-class workflow data. The trigger below rejects
-- self-dependencies and cycles even when a client bypasses the API.
CREATE TABLE IF NOT EXISTS public.task_dependencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  depends_on_task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT task_dependency_not_self CHECK (task_id <> depends_on_task_id),
  CONSTRAINT task_dependency_unique UNIQUE (task_id, depends_on_task_id)
);

CREATE INDEX IF NOT EXISTS idx_task_dependencies_task ON public.task_dependencies(task_id);
CREATE INDEX IF NOT EXISTS idx_task_dependencies_parent ON public.task_dependencies(depends_on_task_id);

CREATE OR REPLACE FUNCTION public.workflow_log_activity(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_publication_id uuid,
  p_actor_id uuid,
  p_description text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.activity_events(
    event_type, entity_type, entity_id, publication_id, actor_id, description, metadata_json
  ) VALUES (
    p_event_type, p_entity_type, p_entity_id, p_publication_id, p_actor_id,
    p_description, COALESCE(p_metadata, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_spread_editable(p_spread_id uuid)
RETURNS public.spreads
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_spread public.spreads;
BEGIN
  SELECT * INTO v_spread
  FROM public.spreads
  WHERE id = p_spread_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'SPREAD_NOT_FOUND';
  END IF;

  IF v_spread.locked_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '55000', MESSAGE = 'SPREAD_LOCKED';
  END IF;

  RETURN v_spread;
END;
$$;

CREATE OR REPLACE FUNCTION public.workflow_upload_asset_version(
  p_asset_id uuid,
  p_actor_id uuid,
  p_original_filename text,
  p_storage_path text,
  p_file_size_bytes bigint DEFAULT NULL,
  p_mime_type text DEFAULT NULL,
  p_checksum text DEFAULT NULL,
  p_change_summary text DEFAULT NULL,
  p_make_current boolean DEFAULT true
) RETURNS public.asset_versions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_asset public.assets;
  v_spread public.spreads;
  v_version public.asset_versions;
  v_number integer;
BEGIN
  SELECT * INTO v_asset FROM public.assets WHERE id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='ASSET_NOT_FOUND'; END IF;

  v_spread := public.assert_spread_editable(v_asset.spread_id);

  SELECT COALESCE(MAX(version_number), 0) + 1 INTO v_number
  FROM public.asset_versions WHERE asset_id = p_asset_id;

  IF p_make_current THEN
    UPDATE public.asset_versions SET is_current = false WHERE asset_id = p_asset_id AND is_current;
  END IF;

  INSERT INTO public.asset_versions(
    asset_id, version_number, original_filename, storage_path, file_size_bytes,
    mime_type, checksum, change_summary, is_current, is_approved, uploaded_by, uploaded_at
  ) VALUES (
    p_asset_id, v_number, p_original_filename, p_storage_path, p_file_size_bytes,
    p_mime_type, p_checksum, p_change_summary, p_make_current, false, p_actor_id, now()
  ) RETURNING * INTO v_version;

  IF p_make_current THEN
    UPDATE public.assets
      SET current_version_id = v_version.id, status = 'In Progress', updated_at = now()
      WHERE id = p_asset_id;
  END IF;

  PERFORM public.workflow_log_activity(
    'asset.version_uploaded', 'Spread', v_asset.spread_id, v_asset.publication_id, p_actor_id,
    format('%s version %s uploaded.', v_asset.title, v_number),
    jsonb_build_object('assetId', p_asset_id, 'versionId', v_version.id, 'versionNumber', v_number)
  );

  RETURN v_version;
END;
$$;

CREATE OR REPLACE FUNCTION public.workflow_switch_asset_version(
  p_asset_id uuid,
  p_version_id uuid,
  p_actor_id uuid,
  p_reason text
) RETURNS public.asset_versions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_asset public.assets;
  v_version public.asset_versions;
BEGIN
  SELECT * INTO v_asset FROM public.assets WHERE id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='ASSET_NOT_FOUND'; END IF;
  PERFORM public.assert_spread_editable(v_asset.spread_id);

  SELECT * INTO v_version FROM public.asset_versions
  WHERE id = p_version_id AND asset_id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='ASSET_VERSION_NOT_FOUND'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.approvals
    WHERE entity_type='Asset' AND entity_id=p_asset_id
      AND decision='Approved' AND revoked_at IS NULL
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='ACTIVE_APPROVAL_EXISTS';
  END IF;

  UPDATE public.asset_versions SET is_current=false WHERE asset_id=p_asset_id AND is_current;
  UPDATE public.asset_versions SET is_current=true WHERE id=p_version_id RETURNING * INTO v_version;
  UPDATE public.assets SET current_version_id=p_version_id, updated_at=now() WHERE id=p_asset_id;

  PERFORM public.workflow_log_activity(
    'asset.current_version_changed', 'Spread', v_asset.spread_id, v_asset.publication_id, p_actor_id,
    format('Current asset version changed to version %s.', v_version.version_number),
    jsonb_build_object('assetId', p_asset_id, 'versionId', p_version_id, 'reason', p_reason)
  );
  RETURN v_version;
END;
$$;

CREATE OR REPLACE FUNCTION public.workflow_complete_review(
  p_review_request_id uuid,
  p_actor_id uuid,
  p_summary text,
  p_decision_recommendation text,
  p_comments jsonb DEFAULT '[]'::jsonb
) RETURNS public.reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_request public.review_requests;
  v_review public.reviews;
  v_comment jsonb;
BEGIN
  SELECT * INTO v_request FROM public.review_requests
  WHERE id=p_review_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='REVIEW_REQUEST_NOT_FOUND'; END IF;
  PERFORM public.assert_spread_editable(v_request.spread_id);

  IF v_request.status <> 'Open' THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='REVIEW_ALREADY_COMPLETED';
  END IF;
  IF v_request.assigned_reviewer <> p_actor_id THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='REVIEWER_MISMATCH';
  END IF;
  IF p_decision_recommendation = 'Changes Requested' AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(COALESCE(p_comments,'[]'::jsonb)) x
    WHERE x->>'severity'='Required Change' AND length(trim(x->>'comment')) > 0
  ) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='REQUIRED_CHANGE_COMMENT_REQUIRED';
  END IF;

  INSERT INTO public.reviews(review_request_id, reviewer_id, summary, decision_recommendation, completed_at)
  VALUES(v_request.id, p_actor_id, p_summary, p_decision_recommendation, now())
  RETURNING * INTO v_review;

  FOR v_comment IN SELECT * FROM jsonb_array_elements(COALESCE(p_comments,'[]'::jsonb)) LOOP
    INSERT INTO public.review_comments(
      review_id, author_id, comment, severity, page_number, x_position, y_position, is_resolved
    ) VALUES (
      v_review.id, p_actor_id, trim(v_comment->>'comment'), v_comment->>'severity',
      NULLIF(v_comment->>'pageNumber','')::integer,
      NULLIF(v_comment->>'xPosition','')::numeric,
      NULLIF(v_comment->>'yPosition','')::numeric,
      false
    );
  END LOOP;

  UPDATE public.review_requests SET status='Completed', completed_at=now() WHERE id=v_request.id;
  UPDATE public.assets SET status = CASE WHEN p_decision_recommendation='Changes Requested'
    THEN 'Changes Requested' ELSE 'Reviewed' END, updated_at=now() WHERE id=v_request.asset_id;

  PERFORM public.workflow_log_activity(
    'review.completed', 'Spread', v_request.spread_id, v_request.publication_id, p_actor_id,
    'Review completed.', jsonb_build_object('reviewRequestId',v_request.id,'reviewId',v_review.id)
  );
  RETURN v_review;
END;
$$;

CREATE OR REPLACE FUNCTION public.workflow_approve_asset_version(
  p_spread_id uuid,
  p_asset_id uuid,
  p_version_id uuid,
  p_actor_id uuid,
  p_approval_type text,
  p_decision_reason text
) RETURNS public.approvals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_asset public.assets;
  v_version public.asset_versions;
  v_approval public.approvals;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_asset FROM public.assets
    WHERE id=p_asset_id AND spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='ASSET_NOT_FOUND'; END IF;
  SELECT * INTO v_version FROM public.asset_versions
    WHERE id=p_version_id AND asset_id=p_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='ASSET_VERSION_NOT_FOUND'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.review_comments rc
    JOIN public.reviews r ON r.id=rc.review_id
    JOIN public.review_requests rr ON rr.id=r.review_request_id
    WHERE rr.asset_version_id=p_version_id
      AND rc.severity='Required Change' AND rc.is_resolved=false
  ) THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='BLOCKING_REVIEW_COMMENTS';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.review_requests WHERE asset_version_id=p_version_id AND status='Completed') THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='REVIEW_REQUIRED';
  END IF;

  INSERT INTO public.approvals(
    entity_type, entity_id, asset_version_id, approval_type, decision,
    decision_reason, approved_by, created_at
  ) VALUES ('Asset',p_asset_id,p_version_id,p_approval_type,'Approved',p_decision_reason,p_actor_id,now())
  RETURNING * INTO v_approval;

  UPDATE public.asset_versions SET is_current=false WHERE asset_id=p_asset_id AND id<>p_version_id;
  UPDATE public.asset_versions SET is_current=true,is_approved=true,approved_at=now() WHERE id=p_version_id;
  UPDATE public.assets SET current_version_id=p_version_id,status='Approved',updated_at=now() WHERE id=p_asset_id;

  PERFORM public.workflow_log_activity(
    'asset.approved','Spread',p_spread_id,v_asset.publication_id,p_actor_id,
    format('%s, version %s, approved.',v_asset.title,v_version.version_number),
    jsonb_build_object('approvalId',v_approval.id,'assetId',p_asset_id,'versionId',p_version_id)
  );
  RETURN v_approval;
END;
$$;

CREATE OR REPLACE FUNCTION public.workflow_revoke_approval(
  p_spread_id uuid,
  p_approval_id uuid,
  p_actor_id uuid,
  p_revocation_reason text
) RETURNS public.approvals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_approval public.approvals;
  v_asset public.assets;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_approval FROM public.approvals
  WHERE id=p_approval_id AND entity_type='Asset' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='APPROVAL_NOT_FOUND'; END IF;
  SELECT * INTO v_asset FROM public.assets
  WHERE id=v_approval.entity_id AND spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='APPROVAL_NOT_FOUND'; END IF;
  IF v_approval.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='APPROVAL_ALREADY_REVOKED';
  END IF;

  UPDATE public.approvals SET revoked_at=now(),revoked_by=p_actor_id,revocation_reason=p_revocation_reason
    WHERE id=p_approval_id RETURNING * INTO v_approval;
  UPDATE public.asset_versions SET is_approved=false,approved_at=NULL WHERE id=v_approval.asset_version_id;
  UPDATE public.assets SET status='Changes Requested',updated_at=now() WHERE id=v_asset.id;

  PERFORM public.workflow_log_activity(
    'approval.revoked','Spread',p_spread_id,v_asset.publication_id,p_actor_id,
    format('Approval revoked for %s.',v_asset.title),
    jsonb_build_object('approvalId',p_approval_id,'reason',p_revocation_reason)
  );
  RETURN v_approval;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_task_dependency_cycle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.task_id = NEW.depends_on_task_id THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='TASK_DEPENDENCY_SELF_REFERENCE';
  END IF;
  IF EXISTS (
    WITH RECURSIVE ancestors(id) AS (
      SELECT NEW.depends_on_task_id
      UNION
      SELECT td.depends_on_task_id
      FROM public.task_dependencies td JOIN ancestors a ON td.task_id=a.id
      WHERE TG_OP='INSERT' OR td.id<>NEW.id
    ) SELECT 1 FROM ancestors WHERE id=NEW.task_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='TASK_DEPENDENCY_CYCLE';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_reject_task_dependency_cycle ON public.task_dependencies;
CREATE TRIGGER trg_reject_task_dependency_cycle
BEFORE INSERT OR UPDATE ON public.task_dependencies
FOR EACH ROW EXECUTE FUNCTION public.reject_task_dependency_cycle();

CREATE OR REPLACE FUNCTION public.workflow_add_task_dependency(
  p_task_id uuid, p_depends_on_task_id uuid, p_actor_id uuid
) RETURNS public.task_dependencies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_task public.tasks;
  v_parent public.tasks;
  v_result public.task_dependencies;
BEGIN
  SELECT * INTO v_task FROM public.tasks WHERE id=p_task_id FOR UPDATE;
  SELECT * INTO v_parent FROM public.tasks WHERE id=p_depends_on_task_id FOR UPDATE;
  IF v_task.id IS NULL OR v_parent.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='TASK_NOT_FOUND'; END IF;
  IF v_task.spread_id IS DISTINCT FROM v_parent.spread_id THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='TASK_DEPENDENCY_SPREAD_MISMATCH'; END IF;
  PERFORM public.assert_spread_editable(v_task.spread_id);
  INSERT INTO public.task_dependencies(task_id,depends_on_task_id,created_by)
    VALUES(p_task_id,p_depends_on_task_id,p_actor_id) RETURNING * INTO v_result;
  RETURN v_result;
END;
$$;

-- Approved decisions may only transition to Superseded; their audited content
-- cannot be edited in place.
CREATE OR REPLACE FUNCTION public.protect_approved_decision()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF OLD.status='Approved' THEN
    IF NEW.status='Superseded'
      AND NEW.decision_code IS NOT DISTINCT FROM OLD.decision_code
      AND NEW.title IS NOT DISTINCT FROM OLD.title
      AND NEW.context IS NOT DISTINCT FROM OLD.context
      AND NEW.options_considered IS NOT DISTINCT FROM OLD.options_considered
      AND NEW.final_decision IS NOT DISTINCT FROM OLD.final_decision
      AND NEW.reason IS NOT DISTINCT FROM OLD.reason
      AND NEW.decision_owner IS NOT DISTINCT FROM OLD.decision_owner
      AND NEW.decision_date IS NOT DISTINCT FROM OLD.decision_date
    THEN RETURN NEW;
    END IF;
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='APPROVED_DECISION_IMMUTABLE';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_protect_approved_decision ON public.decisions;
CREATE TRIGGER trg_protect_approved_decision
BEFORE UPDATE OR DELETE ON public.decisions
FOR EACH ROW EXECUTE FUNCTION public.protect_approved_decision();

-- Generic guards cover direct SQL/PostgREST writes that do not use workflow RPCs.
CREATE OR REPLACE FUNCTION public.reject_edit_on_locked_spread()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE v_spread_id uuid;
BEGIN
  v_spread_id := COALESCE(NEW.spread_id, OLD.spread_id);
  IF v_spread_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.spreads WHERE id=v_spread_id AND locked_at IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE='55000', MESSAGE='SPREAD_LOCKED';
  END IF;
  RETURN COALESCE(NEW,OLD);
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['assets','review_requests','tasks','decisions','character_appearances'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_locked_spread_guard ON public.%I',t);
    EXECUTE format('CREATE TRIGGER trg_locked_spread_guard BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.reject_edit_on_locked_spread()',t);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.reject_asset_version_on_locked_spread()
RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE v_asset_id uuid; v_spread_id uuid;
BEGIN
  v_asset_id:=COALESCE(NEW.asset_id,OLD.asset_id);
  SELECT spread_id INTO v_spread_id FROM public.assets WHERE id=v_asset_id;
  IF EXISTS(SELECT 1 FROM public.spreads WHERE id=v_spread_id AND locked_at IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='SPREAD_LOCKED';
  END IF;
  RETURN COALESCE(NEW,OLD);
END $$;
DROP TRIGGER IF EXISTS trg_locked_spread_guard ON public.asset_versions;
CREATE TRIGGER trg_locked_spread_guard BEFORE INSERT OR UPDATE OR DELETE ON public.asset_versions
FOR EACH ROW EXECUTE FUNCTION public.reject_asset_version_on_locked_spread();

-- Only authenticated users execute workflow functions. RLS still applies to reads;
-- SECURITY DEFINER functions enforce the workflow invariants atomically.
REVOKE ALL ON FUNCTION public.workflow_upload_asset_version(uuid,uuid,text,text,bigint,text,text,text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workflow_switch_asset_version(uuid,uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workflow_complete_review(uuid,uuid,text,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workflow_approve_asset_version(uuid,uuid,uuid,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workflow_revoke_approval(uuid,uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.workflow_add_task_dependency(uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.workflow_upload_asset_version(uuid,uuid,text,text,bigint,text,text,text,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.workflow_switch_asset_version(uuid,uuid,uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.workflow_complete_review(uuid,uuid,text,text,jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.workflow_approve_asset_version(uuid,uuid,uuid,uuid,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.workflow_revoke_approval(uuid,uuid,uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.workflow_add_task_dependency(uuid,uuid,uuid) TO authenticated, service_role;

COMMIT;
