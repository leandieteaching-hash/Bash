# ADR 0014: Approval workflow and editorial gates

## Decision
Studio OS stores formal approvals as tenant-scoped workflows composed of ordered stages, explicit approver assignments, immutable decisions, and auditable evidence. Only the active stage accepts decisions. A rejection returns the workflow to draft for remediation; satisfying the required approval count advances the next stage or completes the workflow.

## Consequences
Approval decisions are distinct from review comments. They are durable evidence, enforced through RBAC and PostgreSQL, and may gate publishing or lifecycle transitions in later increments.
