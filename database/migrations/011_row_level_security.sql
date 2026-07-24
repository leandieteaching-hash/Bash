BEGIN;

-- Supabase authentication link. Existing Studio users are matched to auth.users by email.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'auth' AND table_name = 'users'
  ) THEN
    UPDATE public.users u
       SET auth_user_id = au.id
      FROM auth.users au
     WHERE u.auth_user_id IS NULL
       AND lower(u.email) = lower(au.email);

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_fkey'
    ) THEN
      ALTER TABLE public.users
        ADD CONSTRAINT users_auth_user_id_fkey
        FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_auth_user_id
  ON public.users(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

-- Permissions used by the Spread Manager but absent from the original seed.
INSERT INTO public.permissions(code, description) VALUES
  ('spread.view', 'View spreads and their linked production records'),
  ('asset.view', 'View assets and asset versions'),
  ('review.view', 'View review requests, reviews and comments'),
  ('review.resolve_comment', 'Resolve required-change review comments'),
  ('task.view', 'View production tasks'),
  ('task.edit', 'Create, assign and edit production tasks'),
  ('decision.view', 'View production decisions'),
  ('character.view', 'View character appearances'),
  ('character.edit', 'Add, update and remove character appearances')
ON CONFLICT (code) DO NOTHING;

CREATE SCHEMA IF NOT EXISTS studio_security;
REVOKE ALL ON SCHEMA studio_security FROM PUBLIC;
GRANT USAGE ON SCHEMA studio_security TO authenticated, service_role;

CREATE OR REPLACE FUNCTION studio_security.current_profile_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT u.id
  FROM public.users u
  WHERE u.is_active = true
    AND (
      u.auth_user_id = auth.uid()
      OR (
        u.auth_user_id IS NULL
        AND lower(u.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
    )
  ORDER BY (u.auth_user_id = auth.uid()) DESC
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION studio_security.is_active_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT studio_security.current_profile_id() IS NOT NULL
$$;

CREATE OR REPLACE FUNCTION studio_security.has_permission(p_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.role_permissions rp ON rp.role_id = ur.role_id
    JOIN public.permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = studio_security.current_profile_id()
      AND p.code = p_code
  )
  OR EXISTS (
    SELECT 1
    FROM public.user_roles ur
    JOIN public.roles r ON r.id = ur.role_id
    WHERE ur.user_id = studio_security.current_profile_id()
      AND r.name = 'Administrator'
  )
$$;

CREATE OR REPLACE FUNCTION studio_security.can_view_spread(p_spread_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT studio_security.is_active_user()
     AND EXISTS (SELECT 1 FROM public.spreads s WHERE s.id = p_spread_id)
     AND (
       studio_security.has_permission('spread.view')
       OR studio_security.has_permission('publication.edit')
       OR studio_security.has_permission('spread.edit_text')
       OR studio_security.has_permission('spread.lock')
       OR studio_security.has_permission('asset.view')
       OR studio_security.has_permission('asset.upload')
       OR studio_security.has_permission('asset.approve')
       OR studio_security.has_permission('review.view')
       OR studio_security.has_permission('review.request')
       OR studio_security.has_permission('review.complete')
       OR studio_security.has_permission('task.view')
       OR studio_security.has_permission('task.edit')
       OR studio_security.has_permission('decision.view')
       OR studio_security.has_permission('decision.create')
       OR studio_security.has_permission('decision.approve')
       OR studio_security.has_permission('character.view')
       OR studio_security.has_permission('character.edit')
     )
$$;

CREATE OR REPLACE FUNCTION studio_security.can_view_review_request(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.review_requests rr
    WHERE rr.id = p_request_id
      AND (
        studio_security.can_view_spread(rr.spread_id)
        OR rr.assigned_reviewer = studio_security.current_profile_id()
        OR rr.requested_by = studio_security.current_profile_id()
      )
  )
$$;

CREATE OR REPLACE FUNCTION studio_security.can_view_review(p_review_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reviews r
    WHERE r.id = p_review_id
      AND studio_security.can_view_review_request(r.review_request_id)
  )
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA studio_security FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA studio_security TO authenticated, service_role;

-- SPREADS -------------------------------------------------------------------
ALTER TABLE public.spreads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spreads FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS spreads_select ON public.spreads;
DROP POLICY IF EXISTS spreads_insert ON public.spreads;
DROP POLICY IF EXISTS spreads_update ON public.spreads;
DROP POLICY IF EXISTS spreads_delete ON public.spreads;
CREATE POLICY spreads_select ON public.spreads FOR SELECT TO authenticated
  USING (studio_security.can_view_spread(id));
CREATE POLICY spreads_insert ON public.spreads FOR INSERT TO authenticated
  WITH CHECK (studio_security.has_permission('publication.edit'));
CREATE POLICY spreads_update ON public.spreads FOR UPDATE TO authenticated
  USING (studio_security.can_view_spread(id) AND (
    studio_security.has_permission('publication.edit')
    OR studio_security.has_permission('spread.edit_text')
    OR studio_security.has_permission('spread.lock')
  ))
  WITH CHECK (
    studio_security.has_permission('publication.edit')
    OR studio_security.has_permission('spread.edit_text')
    OR studio_security.has_permission('spread.lock')
  );
CREATE POLICY spreads_delete ON public.spreads FOR DELETE TO authenticated
  USING (studio_security.has_permission('publication.archive'));

-- ASSETS --------------------------------------------------------------------
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS assets_select ON public.assets;
DROP POLICY IF EXISTS assets_insert ON public.assets;
DROP POLICY IF EXISTS assets_update ON public.assets;
DROP POLICY IF EXISTS assets_delete ON public.assets;
CREATE POLICY assets_select ON public.assets FOR SELECT TO authenticated
  USING (spread_id IS NOT NULL AND studio_security.can_view_spread(spread_id));
CREATE POLICY assets_insert ON public.assets FOR INSERT TO authenticated
  WITH CHECK (studio_security.has_permission('asset.upload') AND studio_security.can_view_spread(spread_id));
CREATE POLICY assets_update ON public.assets FOR UPDATE TO authenticated
  USING (studio_security.can_view_spread(spread_id) AND (
    studio_security.has_permission('asset.upload') OR studio_security.has_permission('asset.approve')
  ))
  WITH CHECK (studio_security.can_view_spread(spread_id) AND (
    studio_security.has_permission('asset.upload') OR studio_security.has_permission('asset.approve')
  ));
CREATE POLICY assets_delete ON public.assets FOR DELETE TO authenticated
  USING (studio_security.has_permission('asset.upload') AND studio_security.can_view_spread(spread_id));

ALTER TABLE public.asset_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_versions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS asset_versions_select ON public.asset_versions;
DROP POLICY IF EXISTS asset_versions_insert ON public.asset_versions;
DROP POLICY IF EXISTS asset_versions_update ON public.asset_versions;
DROP POLICY IF EXISTS asset_versions_delete ON public.asset_versions;
CREATE POLICY asset_versions_select ON public.asset_versions FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = asset_id AND studio_security.can_view_spread(a.spread_id)
  ));
CREATE POLICY asset_versions_insert ON public.asset_versions FOR INSERT TO authenticated
  WITH CHECK (studio_security.has_permission('asset.upload') AND EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = asset_id AND studio_security.can_view_spread(a.spread_id)
  ));
CREATE POLICY asset_versions_update ON public.asset_versions FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = asset_id AND studio_security.can_view_spread(a.spread_id)
      AND (studio_security.has_permission('asset.upload') OR studio_security.has_permission('asset.approve'))
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = asset_id AND studio_security.can_view_spread(a.spread_id)
      AND (studio_security.has_permission('asset.upload') OR studio_security.has_permission('asset.approve'))
  ));
CREATE POLICY asset_versions_delete ON public.asset_versions FOR DELETE TO authenticated
  USING (studio_security.has_permission('asset.upload') AND EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = asset_id AND studio_security.can_view_spread(a.spread_id)
  ));

-- REVIEWS -------------------------------------------------------------------
ALTER TABLE public.review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS review_requests_select ON public.review_requests;
DROP POLICY IF EXISTS review_requests_insert ON public.review_requests;
DROP POLICY IF EXISTS review_requests_update ON public.review_requests;
DROP POLICY IF EXISTS review_requests_delete ON public.review_requests;
CREATE POLICY review_requests_select ON public.review_requests FOR SELECT TO authenticated
  USING (studio_security.can_view_review_request(id));
CREATE POLICY review_requests_insert ON public.review_requests FOR INSERT TO authenticated
  WITH CHECK (
    studio_security.has_permission('review.request')
    AND requested_by = studio_security.current_profile_id()
    AND studio_security.can_view_spread(spread_id)
  );
CREATE POLICY review_requests_update ON public.review_requests FOR UPDATE TO authenticated
  USING (
    studio_security.can_view_review_request(id)
    AND (
      assigned_reviewer = studio_security.current_profile_id()
      OR requested_by = studio_security.current_profile_id()
      OR studio_security.has_permission('review.complete')
      OR studio_security.has_permission('review.request')
    )
  )
  WITH CHECK (studio_security.can_view_spread(spread_id));
CREATE POLICY review_requests_delete ON public.review_requests FOR DELETE TO authenticated
  USING (studio_security.has_permission('review.request') AND status = 'Open');

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reviews_select ON public.reviews;
DROP POLICY IF EXISTS reviews_insert ON public.reviews;
DROP POLICY IF EXISTS reviews_update ON public.reviews;
DROP POLICY IF EXISTS reviews_delete ON public.reviews;
CREATE POLICY reviews_select ON public.reviews FOR SELECT TO authenticated
  USING (studio_security.can_view_review_request(review_request_id));
CREATE POLICY reviews_insert ON public.reviews FOR INSERT TO authenticated
  WITH CHECK (
    reviewer_id = studio_security.current_profile_id()
    AND EXISTS (
      SELECT 1 FROM public.review_requests rr
      WHERE rr.id = review_request_id
        AND rr.assigned_reviewer = studio_security.current_profile_id()
        AND rr.status = 'Open'
    )
  );
CREATE POLICY reviews_update ON public.reviews FOR UPDATE TO authenticated
  USING (reviewer_id = studio_security.current_profile_id() OR studio_security.has_permission('review.complete'))
  WITH CHECK (reviewer_id = studio_security.current_profile_id() OR studio_security.has_permission('review.complete'));
CREATE POLICY reviews_delete ON public.reviews FOR DELETE TO authenticated
  USING (false);

ALTER TABLE public.review_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_comments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS review_comments_select ON public.review_comments;
DROP POLICY IF EXISTS review_comments_insert ON public.review_comments;
DROP POLICY IF EXISTS review_comments_update ON public.review_comments;
DROP POLICY IF EXISTS review_comments_delete ON public.review_comments;
CREATE POLICY review_comments_select ON public.review_comments FOR SELECT TO authenticated
  USING (studio_security.can_view_review(review_id));
CREATE POLICY review_comments_insert ON public.review_comments FOR INSERT TO authenticated
  WITH CHECK (
    author_id = studio_security.current_profile_id()
    AND studio_security.can_view_review(review_id)
  );
CREATE POLICY review_comments_update ON public.review_comments FOR UPDATE TO authenticated
  USING (
    studio_security.can_view_review(review_id)
    AND (
      author_id = studio_security.current_profile_id()
      OR studio_security.has_permission('review.resolve_comment')
      OR studio_security.has_permission('review.complete')
    )
  )
  WITH CHECK (studio_security.can_view_review(review_id));
CREATE POLICY review_comments_delete ON public.review_comments FOR DELETE TO authenticated
  USING (author_id = studio_security.current_profile_id() AND status = 'Open');

-- APPROVALS -----------------------------------------------------------------
ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approvals FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS approvals_select ON public.approvals;
DROP POLICY IF EXISTS approvals_insert ON public.approvals;
DROP POLICY IF EXISTS approvals_update ON public.approvals;
DROP POLICY IF EXISTS approvals_delete ON public.approvals;
CREATE POLICY approvals_select ON public.approvals FOR SELECT TO authenticated
  USING (entity_type = 'Asset' AND EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = entity_id AND studio_security.can_view_spread(a.spread_id)
  ));
CREATE POLICY approvals_insert ON public.approvals FOR INSERT TO authenticated
  WITH CHECK (
    entity_type = 'Asset'
    AND approved_by = studio_security.current_profile_id()
    AND studio_security.has_permission('asset.approve')
    AND EXISTS (
      SELECT 1 FROM public.assets a
      WHERE a.id = entity_id AND studio_security.can_view_spread(a.spread_id)
    )
  );
CREATE POLICY approvals_update ON public.approvals FOR UPDATE TO authenticated
  USING (studio_security.has_permission('asset.approve') AND entity_type = 'Asset' AND EXISTS (
    SELECT 1 FROM public.assets a
    WHERE a.id = entity_id AND studio_security.can_view_spread(a.spread_id)
  ))
  WITH CHECK (studio_security.has_permission('asset.approve') AND entity_type = 'Asset');
CREATE POLICY approvals_delete ON public.approvals FOR DELETE TO authenticated
  USING (false);

-- TASKS ---------------------------------------------------------------------
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tasks_select ON public.tasks;
DROP POLICY IF EXISTS tasks_insert ON public.tasks;
DROP POLICY IF EXISTS tasks_update ON public.tasks;
DROP POLICY IF EXISTS tasks_delete ON public.tasks;
CREATE POLICY tasks_select ON public.tasks FOR SELECT TO authenticated
  USING (
    assigned_to = studio_security.current_profile_id()
    OR created_by = studio_security.current_profile_id()
    OR (spread_id IS NOT NULL AND studio_security.can_view_spread(spread_id))
  );
CREATE POLICY tasks_insert ON public.tasks FOR INSERT TO authenticated
  WITH CHECK (
    created_by = studio_security.current_profile_id()
    AND studio_security.has_permission('task.edit')
    AND (spread_id IS NULL OR studio_security.can_view_spread(spread_id))
  );
CREATE POLICY tasks_update ON public.tasks FOR UPDATE TO authenticated
  USING (
    studio_security.has_permission('task.edit')
    OR assigned_to = studio_security.current_profile_id()
    OR created_by = studio_security.current_profile_id()
  )
  WITH CHECK (
    spread_id IS NULL OR studio_security.can_view_spread(spread_id)
  );
CREATE POLICY tasks_delete ON public.tasks FOR DELETE TO authenticated
  USING (studio_security.has_permission('task.edit'));

-- DECISIONS -----------------------------------------------------------------
ALTER TABLE public.decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS decisions_select ON public.decisions;
DROP POLICY IF EXISTS decisions_insert ON public.decisions;
DROP POLICY IF EXISTS decisions_update ON public.decisions;
DROP POLICY IF EXISTS decisions_delete ON public.decisions;
CREATE POLICY decisions_select ON public.decisions FOR SELECT TO authenticated
  USING (
    decision_owner = studio_security.current_profile_id()
    OR (spread_id IS NOT NULL AND studio_security.can_view_spread(spread_id))
  );
CREATE POLICY decisions_insert ON public.decisions FOR INSERT TO authenticated
  WITH CHECK (
    decision_owner = studio_security.current_profile_id()
    AND studio_security.has_permission('decision.create')
    AND (spread_id IS NULL OR studio_security.can_view_spread(spread_id))
  );
CREATE POLICY decisions_update ON public.decisions FOR UPDATE TO authenticated
  USING (
    decision_owner = studio_security.current_profile_id()
    OR studio_security.has_permission('decision.approve')
  )
  WITH CHECK (
    spread_id IS NULL OR studio_security.can_view_spread(spread_id)
  );
CREATE POLICY decisions_delete ON public.decisions FOR DELETE TO authenticated
  USING (status <> 'Approved' AND (
    decision_owner = studio_security.current_profile_id()
    OR studio_security.has_permission('decision.approve')
  ));

-- CHARACTER APPEARANCES ------------------------------------------------------
ALTER TABLE public.character_appearances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.character_appearances FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS character_appearances_select ON public.character_appearances;
DROP POLICY IF EXISTS character_appearances_insert ON public.character_appearances;
DROP POLICY IF EXISTS character_appearances_update ON public.character_appearances;
DROP POLICY IF EXISTS character_appearances_delete ON public.character_appearances;
CREATE POLICY character_appearances_select ON public.character_appearances FOR SELECT TO authenticated
  USING (spread_id IS NOT NULL AND studio_security.can_view_spread(spread_id));
CREATE POLICY character_appearances_insert ON public.character_appearances FOR INSERT TO authenticated
  WITH CHECK (
    studio_security.has_permission('character.edit')
    AND studio_security.can_view_spread(spread_id)
  );
CREATE POLICY character_appearances_update ON public.character_appearances FOR UPDATE TO authenticated
  USING (studio_security.has_permission('character.edit') AND studio_security.can_view_spread(spread_id))
  WITH CHECK (studio_security.has_permission('character.edit') AND studio_security.can_view_spread(spread_id));
CREATE POLICY character_appearances_delete ON public.character_appearances FOR DELETE TO authenticated
  USING (studio_security.has_permission('character.edit') AND studio_security.can_view_spread(spread_id));

-- Table privileges are required in addition to policies. Anonymous users get none.
REVOKE ALL ON public.spreads, public.assets, public.asset_versions,
  public.review_requests, public.reviews, public.review_comments,
  public.approvals, public.tasks, public.decisions, public.character_appearances
  FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.spreads, public.assets, public.asset_versions,
  public.review_requests, public.reviews, public.review_comments,
  public.approvals, public.tasks, public.decisions, public.character_appearances
  TO authenticated;

COMMIT;
