BEGIN;

-- Complete the Spread Manager mutation boundary. Every service-layer write is
-- represented by one PostgreSQL function so validation, state changes, audit
-- logging, and row locking commit or roll back together.

CREATE OR REPLACE FUNCTION public.workflow_add_character_appearance(
  p_spread_id uuid, p_character_id uuid, p_actor_id uuid,
  p_appearance_type text DEFAULT NULL, p_role_in_scene text DEFAULT NULL,
  p_continuity_notes text DEFAULT NULL
) RETURNS public.character_appearances
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_spread public.spreads; v_character public.characters; v_result public.character_appearances;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_spread FROM public.spreads WHERE id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='SPREAD_NOT_FOUND'; END IF;
  SELECT * INTO v_character FROM public.characters WHERE id=p_character_id AND archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='CHARACTER_NOT_FOUND'; END IF;
  INSERT INTO public.character_appearances(publication_id,spread_id,character_id,appearance_type,role_in_scene,continuity_notes)
  VALUES(v_spread.publication_id,p_spread_id,p_character_id,p_appearance_type,p_role_in_scene,p_continuity_notes)
  RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity('spread.character_added','Spread',p_spread_id,v_spread.publication_id,p_actor_id,
    format('%s added to the spread.',v_character.name),jsonb_build_object('characterId',p_character_id,'appearanceId',v_result.id));
  RETURN v_result;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='CHARACTER_ALREADY_LINKED';
END $$;

CREATE OR REPLACE FUNCTION public.workflow_remove_character_appearance(
  p_spread_id uuid, p_appearance_id uuid, p_actor_id uuid
) RETURNS public.character_appearances
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_result public.character_appearances; v_name text;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT ca.* INTO v_result
  FROM public.character_appearances ca
  WHERE ca.id=p_appearance_id AND ca.spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='CHARACTER_APPEARANCE_NOT_FOUND'; END IF;
  SELECT name INTO v_name FROM public.characters WHERE id=v_result.character_id;
  DELETE FROM public.character_appearances WHERE id=p_appearance_id;
  PERFORM public.workflow_log_activity('spread.character_removed','Spread',p_spread_id,v_result.publication_id,p_actor_id,
    format('%s removed from the spread.',v_name),jsonb_build_object('appearanceId',p_appearance_id));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_create_task(
  p_spread_id uuid, p_actor_id uuid, p_title text, p_description text DEFAULT NULL,
  p_department text DEFAULT NULL, p_priority text DEFAULT 'Medium',
  p_assigned_to uuid DEFAULT NULL, p_due_date date DEFAULT NULL
) RETURNS public.tasks
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_spread public.spreads; v_result public.tasks;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_spread FROM public.spreads WHERE id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='SPREAD_NOT_FOUND'; END IF;
  INSERT INTO public.tasks(publication_id,spread_id,title,description,department,status,priority,assigned_to,due_date,created_by)
  VALUES(v_spread.publication_id,p_spread_id,p_title,p_description,p_department,'Not Started',p_priority,p_assigned_to,p_due_date,p_actor_id)
  RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity('task.created','Spread',p_spread_id,v_spread.publication_id,p_actor_id,
    format('Task created: %s.',v_result.title),jsonb_build_object('taskId',v_result.id));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_update_task(
  p_spread_id uuid, p_task_id uuid, p_actor_id uuid, p_patch jsonb
) RETURNS public.tasks
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_task public.tasks; v_result public.tasks; v_status text;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_task FROM public.tasks WHERE id=p_task_id AND spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='TASK_NOT_FOUND'; END IF;
  v_status := COALESCE(p_patch->>'status',v_task.status);
  UPDATE public.tasks SET
    status=CASE WHEN p_patch ? 'status' THEN p_patch->>'status' ELSE status END,
    priority=CASE WHEN p_patch ? 'priority' THEN p_patch->>'priority' ELSE priority END,
    assigned_to=CASE WHEN p_patch ? 'assignedTo' THEN NULLIF(p_patch->>'assignedTo','')::uuid ELSE assigned_to END,
    due_date=CASE WHEN p_patch ? 'dueDate' THEN NULLIF(p_patch->>'dueDate','')::date ELSE due_date END,
    blocked_reason=CASE WHEN p_patch ? 'blockedReason' THEN NULLIF(p_patch->>'blockedReason','') ELSE blocked_reason END,
    completed_at=CASE WHEN v_status='Completed' THEN COALESCE(completed_at,now()) WHEN p_patch ? 'status' THEN NULL ELSE completed_at END
  WHERE id=p_task_id RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity(CASE WHEN v_status='Completed' THEN 'task.completed' ELSE 'task.updated' END,
    'Spread',p_spread_id,v_task.publication_id,p_actor_id,format('Task updated: %s.',v_task.title),
    jsonb_build_object('taskId',p_task_id,'patch',p_patch));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_create_decision(
  p_spread_id uuid, p_actor_id uuid, p_decision_code text, p_title text,
  p_context text, p_options_considered jsonb, p_final_decision text,
  p_reason text, p_status text DEFAULT 'Proposed'
) RETURNS public.decisions
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_spread public.spreads; v_result public.decisions;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_spread FROM public.spreads WHERE id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='SPREAD_NOT_FOUND'; END IF;
  INSERT INTO public.decisions(decision_code,publication_id,spread_id,title,context,options_considered,final_decision,reason,decision_owner,decision_date,status)
  VALUES(p_decision_code,v_spread.publication_id,p_spread_id,p_title,p_context,COALESCE(p_options_considered,'[]'::jsonb),p_final_decision,p_reason,p_actor_id,current_date,p_status)
  RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity('decision.created','Spread',p_spread_id,v_spread.publication_id,p_actor_id,
    format('Decision recorded: %s.',v_result.title),jsonb_build_object('decisionId',v_result.id));
  RETURN v_result;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='DUPLICATE_CODE';
END $$;

CREATE OR REPLACE FUNCTION public.workflow_approve_decision(
  p_spread_id uuid, p_decision_id uuid, p_actor_id uuid
) RETURNS public.decisions
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_result public.decisions;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_result FROM public.decisions WHERE id=p_decision_id AND spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='DECISION_NOT_FOUND'; END IF;
  IF v_result.status='Approved' THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='DECISION_ALREADY_APPROVED'; END IF;
  IF v_result.status='Superseded' THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='DECISION_SUPERSEDED'; END IF;
  UPDATE public.decisions SET status='Approved',decision_owner=p_actor_id,decision_date=current_date
  WHERE id=p_decision_id RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity('decision.approved','Spread',p_spread_id,v_result.publication_id,p_actor_id,
    format('Decision approved: %s.',v_result.title),jsonb_build_object('decisionId',p_decision_id));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_supersede_decision(
  p_spread_id uuid, p_decision_id uuid, p_actor_id uuid, p_decision_code text,
  p_title text, p_context text, p_options_considered jsonb,
  p_final_decision text, p_reason text
) RETURNS public.decisions
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_old public.decisions; v_new public.decisions;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_old FROM public.decisions WHERE id=p_decision_id AND spread_id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='DECISION_NOT_FOUND'; END IF;
  IF v_old.status<>'Approved' THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='DECISION_NOT_APPROVED'; END IF;
  IF EXISTS(SELECT 1 FROM public.decisions WHERE supersedes_decision_id=p_decision_id) THEN
    RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='DECISION_ALREADY_SUPERSEDED';
  END IF;
  INSERT INTO public.decisions(decision_code,publication_id,spread_id,title,context,options_considered,final_decision,reason,decision_owner,decision_date,status,supersedes_decision_id)
  VALUES(p_decision_code,v_old.publication_id,p_spread_id,p_title,p_context,COALESCE(p_options_considered,'[]'::jsonb),p_final_decision,p_reason,p_actor_id,current_date,'Approved',p_decision_id)
  RETURNING * INTO v_new;
  UPDATE public.decisions SET status='Superseded' WHERE id=p_decision_id;
  PERFORM public.workflow_log_activity('decision.superseded','Spread',p_spread_id,v_old.publication_id,p_actor_id,
    format('Decision superseded: %s.',v_old.title),jsonb_build_object('oldDecisionId',p_decision_id,'newDecisionId',v_new.id));
  RETURN v_new;
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='DUPLICATE_CODE';
END $$;

CREATE OR REPLACE FUNCTION public.workflow_create_review_request(
  p_spread_id uuid, p_asset_id uuid, p_asset_version_id uuid, p_actor_id uuid,
  p_assigned_reviewer uuid, p_review_type text, p_instructions text DEFAULT NULL,
  p_due_date date DEFAULT NULL
) RETURNS public.review_requests
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_spread public.spreads; v_asset public.assets; v_version public.asset_versions; v_reviewer public.users; v_result public.review_requests;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT * INTO v_spread FROM public.spreads WHERE id=p_spread_id FOR UPDATE;
  SELECT * INTO v_asset FROM public.assets WHERE id=p_asset_id AND spread_id=p_spread_id FOR UPDATE;
  SELECT * INTO v_version FROM public.asset_versions WHERE id=p_asset_version_id AND asset_id=p_asset_id FOR UPDATE;
  SELECT * INTO v_reviewer FROM public.users WHERE id=p_assigned_reviewer;
  IF v_spread.id IS NULL OR v_asset.id IS NULL OR v_version.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='INVALID_REVIEW_CONTEXT'; END IF;
  IF v_reviewer.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='REVIEWER_NOT_FOUND'; END IF;
  IF NOT v_reviewer.is_active THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='REVIEWER_INACTIVE'; END IF;
  IF EXISTS(SELECT 1 FROM public.review_requests WHERE asset_version_id=p_asset_version_id AND assigned_reviewer=p_assigned_reviewer AND status='Open') THEN
    RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='DUPLICATE_REVIEW_REQUEST';
  END IF;
  INSERT INTO public.review_requests(publication_id,spread_id,asset_id,asset_version_id,requested_by,assigned_reviewer,review_type,instructions,due_date,status)
  VALUES(v_spread.publication_id,p_spread_id,p_asset_id,p_asset_version_id,p_actor_id,p_assigned_reviewer,p_review_type,p_instructions,p_due_date,'Open')
  RETURNING * INTO v_result;
  UPDATE public.assets SET status='Ready for Review',updated_at=now() WHERE id=p_asset_id;
  PERFORM public.workflow_log_activity('review.requested','Spread',p_spread_id,v_spread.publication_id,p_actor_id,
    format('Review requested for %s, version %s.',v_asset.title,v_version.version_number),jsonb_build_object('reviewRequestId',v_result.id));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_resolve_review_comment(
  p_spread_id uuid, p_comment_id uuid, p_actor_id uuid, p_resolution_note text
) RETURNS public.review_comments
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_result public.review_comments; v_publication_id uuid;
BEGIN
  PERFORM public.assert_spread_editable(p_spread_id);
  SELECT rc.* INTO v_result
  FROM public.review_comments rc JOIN public.reviews r ON r.id=rc.review_id
  JOIN public.review_requests rr ON rr.id=r.review_request_id
  WHERE rc.id=p_comment_id AND rr.spread_id=p_spread_id FOR UPDATE OF rc;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='REVIEW_COMMENT_NOT_FOUND'; END IF;
  SELECT rr.publication_id INTO v_publication_id FROM public.reviews r JOIN public.review_requests rr ON rr.id=r.review_request_id WHERE r.id=v_result.review_id;
  IF v_result.is_resolved THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='COMMENT_ALREADY_RESOLVED'; END IF;
  UPDATE public.review_comments SET is_resolved=true,resolution_note=p_resolution_note,resolved_by=p_actor_id,resolved_at=now()
  WHERE id=p_comment_id RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity('review.comment_resolved','Spread',p_spread_id,v_publication_id,p_actor_id,
    'A required review comment was resolved.',jsonb_build_object('commentId',p_comment_id,'resolutionNote',p_resolution_note));
  RETURN v_result;
END $$;

CREATE OR REPLACE FUNCTION public.workflow_set_spread_lock(
  p_spread_id uuid, p_actor_id uuid, p_lock boolean, p_reason text
) RETURNS public.spreads
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_result public.spreads;
BEGIN
  SELECT * INTO v_result FROM public.spreads WHERE id=p_spread_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='SPREAD_NOT_FOUND'; END IF;
  IF p_lock AND v_result.locked_at IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='SPREAD_ALREADY_LOCKED'; END IF;
  IF NOT p_lock AND v_result.locked_at IS NULL THEN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='SPREAD_NOT_LOCKED'; END IF;
  UPDATE public.spreads SET locked_at=CASE WHEN p_lock THEN now() ELSE NULL END,
    locked_by=CASE WHEN p_lock THEN p_actor_id ELSE NULL END,
    lock_reason=CASE WHEN p_lock THEN p_reason ELSE NULL END
  WHERE id=p_spread_id RETURNING * INTO v_result;
  PERFORM public.workflow_log_activity(CASE WHEN p_lock THEN 'spread.locked' ELSE 'spread.unlocked' END,
    'Spread',p_spread_id,v_result.publication_id,p_actor_id,
    CASE WHEN p_lock THEN format('Spread locked: %s',p_reason) ELSE format('Spread unlocked: %s',p_reason) END,
    jsonb_build_object('reason',p_reason));
  RETURN v_result;
END $$;

-- Remove a dependency through the same transactional boundary used to add one.
CREATE OR REPLACE FUNCTION public.workflow_remove_task_dependency(
  p_task_id uuid, p_depends_on_task_id uuid, p_actor_id uuid
) RETURNS public.task_dependencies
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_task public.tasks; v_result public.task_dependencies;
BEGIN
  SELECT * INTO v_task FROM public.tasks WHERE id=p_task_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='TASK_NOT_FOUND'; END IF;
  PERFORM public.assert_spread_editable(v_task.spread_id);
  DELETE FROM public.task_dependencies WHERE task_id=p_task_id AND depends_on_task_id=p_depends_on_task_id RETURNING * INTO v_result;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='TASK_DEPENDENCY_NOT_FOUND'; END IF;
  PERFORM public.workflow_log_activity('task.dependency_removed','Spread',v_task.spread_id,v_task.publication_id,p_actor_id,
    format('Task dependency removed from %s.',v_task.title),jsonb_build_object('taskId',p_task_id,'dependsOnTaskId',p_depends_on_task_id));
  RETURN v_result;
END $$;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'workflow_add_character_appearance','workflow_remove_character_appearance','workflow_create_task','workflow_update_task',
      'workflow_create_decision','workflow_approve_decision','workflow_supersede_decision','workflow_create_review_request',
      'workflow_resolve_review_comment','workflow_set_spread_lock','workflow_remove_task_dependency')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC',r.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role',r.signature);
  END LOOP;
END $$;

COMMIT;
