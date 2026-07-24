# Approval Workflow

Approval workflows belong to one spread and one organization. Each workflow contains ordered stages, each stage defines a required approval count, and assignments identify eligible approvers. Decisions are made through `decide_approval_stage`, which locks the assignment, stage, and workflow; verifies the authenticated approver; records immutable evidence; and advances, rejects, or completes the workflow atomically.

Permissions: `approvals.read`, `approvals.create`, `approvals.assign`, `approvals.decide`, `approvals.override`, and `approvals.gates.manage`.

Every mutation writes an audit event and an event-outbox record. Future publishing gates should require a completed workflow rather than trusting UI state.
