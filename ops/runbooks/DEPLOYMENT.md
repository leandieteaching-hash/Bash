# Deployment Runbook

## Preconditions

- CI has passed from a clean `npm ci` installation.
- The image is addressed by an immutable digest.
- Database migrations have been reviewed for forward and backward compatibility.
- A current database backup has completed and its checksum has been verified.

## Procedure

1. Deploy to staging with the exact production candidate image.
2. Run migration integration tests, application smoke tests and security-header checks.
3. Record the image digest, migration range and approver in the change record.
4. Deploy to production with `IMAGE_REF` and `KUBE_NAMESPACE` set.
5. Observe error rate, latency, authentication failures and database health for at least one normal traffic interval.
6. Mark the release complete only after health and business-path checks pass.

## Stop conditions

Stop or roll back for failed readiness checks, sustained elevated error rate, authorization regressions, migration errors, data-integrity errors or unavailable rollback prerequisites.
