-- PR-014 Approval workflow and editorial gates
create table if not exists approval_workflows (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), spread_id uuid not null,
 name text not null, status text not null default 'draft' check(status in ('draft','active','completed','cancelled')),
 current_stage integer not null default 1 check(current_stage>0), version integer not null default 1,
 created_by uuid, completed_by uuid, completed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists approval_stages (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), workflow_id uuid not null references approval_workflows(id) on delete cascade,
 stage_number integer not null check(stage_number>0), name text not null, required_approvals integer not null default 1 check(required_approvals>0), status text not null default 'pending' check(status in ('pending','active','approved','rejected','skipped')),
 activated_at timestamptz, completed_at timestamptz, unique(workflow_id,stage_number)
);
create table if not exists approval_assignments (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), stage_id uuid not null references approval_stages(id) on delete cascade,
 approver_id uuid not null, status text not null default 'pending' check(status in ('pending','approved','rejected','abstained')),
 assigned_by uuid, assigned_at timestamptz not null default now(), decided_at timestamptz, unique(stage_id,approver_id)
);
create table if not exists approval_decisions (
 id uuid primary key default gen_random_uuid(), organisation_id uuid not null references organisations(id), workflow_id uuid not null references approval_workflows(id) on delete cascade,
 stage_id uuid not null references approval_stages(id) on delete cascade, assignment_id uuid references approval_assignments(id) on delete set null,
 decision text not null check(decision in ('approved','rejected','abstained')), rationale text, evidence jsonb not null default '{}'::jsonb,
 decided_by uuid not null, created_at timestamptz not null default now()
);
create index if not exists approval_workflows_tenant_spread_idx on approval_workflows(organisation_id,spread_id,status);
create index if not exists approval_stages_workflow_idx on approval_stages(workflow_id,stage_number);
create index if not exists approval_assignments_approver_idx on approval_assignments(organisation_id,approver_id,status);
create index if not exists approval_decisions_stage_idx on approval_decisions(stage_id,created_at);

alter table approval_workflows enable row level security; alter table approval_stages enable row level security; alter table approval_assignments enable row level security; alter table approval_decisions enable row level security;
create policy approval_workflows_tenant on approval_workflows using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy approval_stages_tenant on approval_stages using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy approval_assignments_tenant on approval_assignments using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());
create policy approval_decisions_tenant on approval_decisions using (organisation_id=current_organisation_id()) with check (organisation_id=current_organisation_id());

insert into platform_permissions(code,description) values
 ('approvals.read','Read approval workflows and decisions'),('approvals.create','Create approval workflows'),('approvals.assign','Assign approval stages'),
 ('approvals.decide','Approve or reject assigned work'),('approvals.override','Override or cancel approval workflows'),('approvals.gates.manage','Manage editorial approval gates')
on conflict(code) do update set description=excluded.description;

create or replace function decide_approval_stage(p_assignment_id uuid,p_organisation_id uuid,p_user_id uuid,p_decision text,p_rationale text default null)
returns table(workflow_id uuid,stage_id uuid,stage_status text,workflow_status text,current_stage integer) language plpgsql security definer set search_path=public as $$
declare v_assignment approval_assignments%rowtype; v_stage approval_stages%rowtype; v_workflow approval_workflows%rowtype; v_approved integer; v_rejected integer; v_next approval_stages%rowtype;
begin
 if p_decision not in ('approved','rejected','abstained') then raise exception 'INVALID_APPROVAL_DECISION'; end if;
 select * into v_assignment from approval_assignments where id=p_assignment_id and organisation_id=p_organisation_id for update;
 if not found or v_assignment.approver_id<>p_user_id then raise exception 'APPROVAL_ASSIGNMENT_NOT_FOUND'; end if;
 if v_assignment.status<>'pending' then raise exception 'APPROVAL_ALREADY_DECIDED'; end if;
 select * into v_stage from approval_stages where id=v_assignment.stage_id and organisation_id=p_organisation_id for update;
 select * into v_workflow from approval_workflows where id=v_stage.workflow_id and organisation_id=p_organisation_id for update;
 if v_workflow.status<>'active' or v_stage.status<>'active' then raise exception 'APPROVAL_STAGE_NOT_ACTIVE'; end if;
 update approval_assignments set status=p_decision,decided_at=now() where id=p_assignment_id;
 insert into approval_decisions(organisation_id,workflow_id,stage_id,assignment_id,decision,rationale,decided_by) values(p_organisation_id,v_workflow.id,v_stage.id,p_assignment_id,p_decision,p_rationale,p_user_id);
 select count(*) filter(where status='approved'),count(*) filter(where status='rejected') into v_approved,v_rejected from approval_assignments where stage_id=v_stage.id;
 if v_rejected>0 then
  update approval_stages set status='rejected',completed_at=now() where id=v_stage.id;
  update approval_workflows set status='draft',updated_at=now(),version=version+1 where id=v_workflow.id;
 elsif v_approved>=v_stage.required_approvals then
  update approval_stages set status='approved',completed_at=now() where id=v_stage.id;
  select * into v_next from approval_stages where workflow_id=v_workflow.id and stage_number>v_stage.stage_number order by stage_number limit 1;
  if found then
   update approval_stages set status='active',activated_at=now() where id=v_next.id;
   update approval_workflows set current_stage=v_next.stage_number,updated_at=now(),version=version+1 where id=v_workflow.id;
  else
   update approval_workflows set status='completed',completed_by=p_user_id,completed_at=now(),updated_at=now(),version=version+1 where id=v_workflow.id;
  end if;
 end if;
 return query select w.id,s.id,s.status,w.status,w.current_stage from approval_workflows w join approval_stages s on s.id=v_stage.id where w.id=v_workflow.id;
end $$;
