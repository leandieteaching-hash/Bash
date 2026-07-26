# Customer onboarding and migration

Every onboarding uses a dry-run-first, idempotent import. The source is frozen or incrementally captured, files are checksummed, schemas are validated, tenant mappings are approved, and import counts are reconciled before cutover.

## Gates

1. Data-processing agreement and named customer owner.
2. Source inventory, retention classification, and field mapping.
3. Dry-run in an isolated tenant.
4. Referential-integrity, duplicate, checksum, and permission checks.
5. Customer acceptance of sampled records and totals.
6. Timed cutover with rollback criteria and support coverage.
7. Post-cutover reconciliation and source disposal evidence.

Imports must be resumable and keyed by an immutable idempotency key. Failed runs retain evidence but must not expose source records outside the target tenant.
