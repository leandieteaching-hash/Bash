# Studio OS v1.0 release hardening

The v1.0 release is permitted only from a clean, protected commit with a verified lockfile, reproducible `npm ci`, lint, typecheck, unit and integration tests, production build, accessibility evidence, migration rehearsal, staging E2E, performance thresholds, DAST, dependency and secret scans, backup/restore evidence, rollback rehearsal, and an approved go/no-go record.

## Release blockers

Critical or high security findings, cross-tenant access, data loss, failed restore, inaccessible critical workflow, migration irreversibility without an approved recovery path, unbounded error rates, unsigned artefacts, or missing provenance are automatic no-go conditions.

## Release procedure

1. Freeze scope and record the exact commit.
2. Generate lockfile and dependency/SBOM evidence in an online trusted runner.
3. Build once and promote the same immutable image through staging and production.
4. Execute all mandatory gates and retain logs/checksums.
5. Obtain engineering, security, product, support and operations approvals.
6. Create a signed annotated `v1.0.0` tag only after the go/no-go tool reports GO.
7. Monitor the release and retain an immediately executable rollback path.
