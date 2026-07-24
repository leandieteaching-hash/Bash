# Studio OS Production Operations

## Scope
This package adds the enterprise operating layer: application health, metrics, structured logging integration points, alerts, backups, recovery verification, CI/CD, and security scanning.

## Monitoring and metrics
- `GET /api/operations/health` is the unauthenticated platform health endpoint used by load balancers and smoke tests.
- `GET /api/operations/metrics` exposes a Prometheus-compatible baseline. Protect it at the network edge in production.
- The System Health command centre is available at `/admin/system-health` and should be permission-gated with `system.health.view`.
- Connect runtime telemetry to OpenTelemetry and send traces, logs, and metrics to the approved provider.

## Logging
Use structured JSON records with: timestamp, severity, environment, release, request ID, actor ID, book ID, spread ID, operation, duration, status, and error code. Never log access tokens, signed URLs, passwords, file contents, or sensitive personal data.

## Backups
`ops/scripts/backup.sh` creates a custom-format PostgreSQL backup and SHA-256 checksum. Production schedules should also protect Supabase Storage objects and configuration secrets. Encrypt backups, store them in a separate account/region, and enforce retention locks.

## Disaster recovery
Run `ops/scripts/verify-restore.sh` against an isolated recovery database. Minimum operational targets should be approved by the business; a practical starting point is RPO <= 24 hours and RTO <= 4 hours. Test restoration quarterly and record evidence in `backup_verifications`.

## Deployment
The deployment workflow provides environment approvals, an immutable build, and a post-deploy health check. Connect `ops/scripts/deploy.sh` to the chosen host. Recommended promotion: migration compatibility check, staging verification, backup checkpoint, canary, smoke tests, then production promotion. Roll back the application independently of backward-compatible migrations.

## Security scanning
CI performs dependency auditing and secret scanning. Add CodeQL/SAST, container/image scanning, IaC scanning, DAST against staging, and software-bill-of-material generation when the hosting implementation is selected.

## Alerting
Starter Prometheus rules are in `ops/alerts/prometheus.rules.yml`. Route critical alerts to the on-call channel and warnings to the operations queue. Every alert should link to a runbook and include service, environment, release, and correlation ID.

## Runbooks
Maintain procedures for application outage, database saturation, realtime disruption, storage failure, notification backlog, export worker failure, compromised credentials, and recovery from backup. Each incident requires an owner, timeline, resolution, and follow-up actions.
