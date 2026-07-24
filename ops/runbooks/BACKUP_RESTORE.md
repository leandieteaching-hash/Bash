# Backup and Restore Runbook

## Targets

- Production database: daily full logical backup plus provider point-in-time recovery.
- Object storage: versioning and lifecycle retention enabled.
- Secrets and configuration: retained in the managed secret store, not in database backups.

## Verification

Every backup must have a SHA-256 checksum. At least monthly, restore the newest backup into an isolated database and run `ops/scripts/restore-test.sh`. Record backup timestamp, restore duration, row-count checks, schema version, and operator.

## Recovery objectives

Set and approve explicit RPO and RTO values before production launch. Test that the backup frequency and measured restoration time satisfy them.
