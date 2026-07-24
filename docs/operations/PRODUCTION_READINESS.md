# Production Readiness Gates

A release is eligible for production only when all gates are green:

1. Reproducibility: committed npm lockfile and clean `npm ci`.
2. Quality: formatting, lint, TypeScript, unit/structural, integration and E2E tests.
3. Build: successful Next.js production build and immutable container image.
4. Performance: agreed p95/p99 latency and error-rate thresholds under representative load.
5. Security: secret scan, dependency audit, static review, DAST and independent penetration-test sign-off.
6. Data safety: migration rehearsal, verified backup and successful isolated restore.
7. Operations: deployment, rollback, incident and recovery runbooks exercised.
