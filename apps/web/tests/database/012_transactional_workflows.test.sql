BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(11);

-- These tests run against the Meet Mia seed and roll back completely.
CREATE TEMP TABLE fixture AS
SELECT
  s.id spread_id, s.publication_id,
  a.id asset_id,
  u.id actor_id
FROM public.spreads s
JOIN public.assets a ON a.spread_id=s.id
CROSS JOIN LATERAL (SELECT id FROM public.users WHERE is_active=true ORDER BY created_at LIMIT 1) u
WHERE s.locked_at IS NULL
ORDER BY s.spread_number, a.created_at
LIMIT 1;

SELECT ok((SELECT count(*)=1 FROM fixture),'Meet Mia fixture spread, asset, and active user are available');

-- 1. Uploading v2 preserves v1.
DO $$
DECLARE f record; v1 uuid; v2 public.asset_versions;
BEGIN
 SELECT * INTO f FROM fixture;
 SELECT id INTO v1 FROM public.asset_versions WHERE asset_id=f.asset_id ORDER BY version_number LIMIT 1;
 SELECT * INTO v2 FROM public.workflow_upload_asset_version(f.asset_id,f.actor_id,'integration-v2.png','tests/integration-v2.png',123,'image/png','test-v2','integration test',true);
 PERFORM set_config('test.v1',v1::text,false); PERFORM set_config('test.v2',v2.id::text,false);
END $$;
SELECT ok(EXISTS(SELECT 1 FROM public.asset_versions WHERE id=current_setting('test.v1')::uuid),'version 1 still exists after version 2 upload');
SELECT isnt(current_setting('test.v1'),current_setting('test.v2'),'version 2 has a distinct immutable row');
SELECT is((SELECT count(*)::int FROM public.asset_versions WHERE asset_id=(SELECT asset_id FROM fixture)),
          (SELECT max(version_number)::int FROM public.asset_versions WHERE asset_id=(SELECT asset_id FROM fixture)),
          'version rows are retained rather than overwritten');

-- Build a completed review with an unresolved required change for v2.
DO $$
DECLARE f record; rr uuid; r public.reviews;
BEGIN
 SELECT * INTO f FROM fixture;
 INSERT INTO public.review_requests(publication_id,spread_id,asset_id,asset_version_id,requested_by,assigned_reviewer,review_type,status)
 VALUES(f.publication_id,f.spread_id,f.asset_id,current_setting('test.v2')::uuid,f.actor_id,f.actor_id,'Integration','Open') RETURNING id INTO rr;
 SELECT * INTO r FROM public.workflow_complete_review(rr,f.actor_id,'Needs correction','Changes Requested',
   '[{"comment":"Fix the illustration","severity":"Required Change"}]'::jsonb);
 PERFORM set_config('test.review',r.id::text,false);
END $$;
SELECT throws_ok(format(
  'SELECT public.workflow_approve_asset_version(%L,%L,%L,%L,%L,%L)',
  (SELECT spread_id FROM fixture),(SELECT asset_id FROM fixture),current_setting('test.v2'),(SELECT actor_id FROM fixture),'Production','Ready'),
  '55000','BLOCKING_REVIEW_COMMENTS','approval fails with unresolved required-change comments');

-- Resolve, approve, then verify current switching is blocked by active approval.
UPDATE public.review_comments SET is_resolved=true,resolved_at=now(),resolved_by=(SELECT actor_id FROM fixture)
WHERE review_id=current_setting('test.review')::uuid;
DO $$ DECLARE f record; ap public.approvals; BEGIN SELECT * INTO f FROM fixture;
 SELECT * INTO ap FROM public.workflow_approve_asset_version(f.spread_id,f.asset_id,current_setting('test.v2')::uuid,f.actor_id,'Production','Approved in test');
 PERFORM set_config('test.approval',ap.id::text,false); END $$;
SELECT throws_ok(format(
  'SELECT public.workflow_switch_asset_version(%L,%L,%L,%L)',
  (SELECT asset_id FROM fixture),current_setting('test.v1'),(SELECT actor_id FROM fixture),'try old version'),
  '55000','ACTIVE_APPROVAL_EXISTS','changing current version fails while an active approval exists');

-- Task dependency cycles.
DO $$ DECLARE f record; a uuid; b uuid; BEGIN SELECT * INTO f FROM fixture;
 INSERT INTO public.tasks(publication_id,spread_id,title,status,priority,created_by) VALUES(f.publication_id,f.spread_id,'Cycle A','Not Started','Medium',f.actor_id) RETURNING id INTO a;
 INSERT INTO public.tasks(publication_id,spread_id,title,status,priority,created_by) VALUES(f.publication_id,f.spread_id,'Cycle B','Not Started','Medium',f.actor_id) RETURNING id INTO b;
 PERFORM public.workflow_add_task_dependency(a,b,f.actor_id); PERFORM set_config('test.task_a',a::text,false); PERFORM set_config('test.task_b',b::text,false); END $$;
SELECT throws_ok(format('SELECT public.workflow_add_task_dependency(%L,%L,%L)',current_setting('test.task_b'),current_setting('test.task_a'),(SELECT actor_id FROM fixture)),
  '23514','TASK_DEPENDENCY_CYCLE','task dependency cycles are rejected');

-- Locked spread blocks edits through RPC and direct row writes.
UPDATE public.spreads SET locked_at=now(),locked_by=(SELECT actor_id FROM fixture),lock_reason='integration test' WHERE id=(SELECT spread_id FROM fixture);
SELECT throws_ok(format('SELECT public.workflow_upload_asset_version(%L,%L,%L,%L)',(SELECT asset_id FROM fixture),(SELECT actor_id FROM fixture),'locked.png','tests/locked.png'),
  '55000','SPREAD_LOCKED','locked spreads cannot upload asset versions');
SELECT throws_ok(format('UPDATE public.tasks SET title=%L WHERE id=%L','Illegal edit',current_setting('test.task_a')),
  '55000','SPREAD_LOCKED','locked spreads reject direct task edits');
UPDATE public.spreads SET locked_at=NULL,locked_by=NULL,lock_reason=NULL WHERE id=(SELECT spread_id FROM fixture);

-- Approved decisions are immutable, but may transition to Superseded without content changes.
DO $$ DECLARE f record; d uuid; BEGIN SELECT * INTO f FROM fixture;
 INSERT INTO public.decisions(decision_code,publication_id,spread_id,title,final_decision,reason,decision_owner,decision_date,status)
 VALUES('TEST-IMMUTABLE-'||substr(gen_random_uuid()::text,1,8),f.publication_id,f.spread_id,'Approved test decision','Keep it','Test reason',f.actor_id,current_date,'Approved') RETURNING id INTO d;
 PERFORM set_config('test.decision',d::text,false); END $$;
SELECT throws_ok(format('UPDATE public.decisions SET final_decision=%L WHERE id=%L','Changed illegally',current_setting('test.decision')),
  '55000','APPROVED_DECISION_IMMUTABLE','approved decisions cannot be modified');
SELECT lives_ok(format('UPDATE public.decisions SET status=%L WHERE id=%L','Superseded',current_setting('test.decision')),
  'approved decisions may transition to Superseded without rewriting history');

SELECT * FROM finish();
ROLLBACK;
