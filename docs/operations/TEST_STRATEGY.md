# Test Strategy

## Layers

- Structural release tests verify required routes, migrations, RLS declarations, permissions and documentation.
- Type checking and linting validate the TypeScript and Next.js application from a clean locked dependency tree.
- Database integration tests apply migrations to an isolated database and verify critical schema invariants.
- Playwright E2E tests exercise authenticated asset, review, approval and spread workflows against an isolated Supabase project.
- k6 performance tests enforce error-rate and latency budgets against a deployed staging environment.
- Security tests combine history-wide secret scanning, static review, dependency audit, CodeQL, runtime header checks and DAST.

## Release evidence

CI reports and artifacts must be retained with the release identifier. Failed or skipped required jobs block production release; environment-dependent jobs may only be skipped when the release is explicitly non-production.
