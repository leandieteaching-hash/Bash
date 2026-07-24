# Rollback Runbook

1. Declare the incident and freeze further deployments.
2. Capture the current image digest, logs, metrics and correlation identifiers.
3. Determine whether the database migration is backward compatible.
4. Run `ops/scripts/rollback.sh [revision]` for application-only rollback.
5. For incompatible schema changes, follow the migration-specific recovery plan; never reverse a destructive migration without a verified backup.
6. Verify login, tenant isolation, asset access, editor save, review and approval flows.
7. Document cause, impact, recovery time and corrective actions.
