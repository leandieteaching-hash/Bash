# Studio OS

Enterprise publishing operations platform.

## Repository layout

- `apps/web` — Next.js application and application tests
- `database/migrations` — versioned PostgreSQL migrations
- `docs/architecture` — architecture and operating documentation
- `infrastructure` — deployment and observability assets
- `.github/workflows` — continuous integration and release automation

## Verify locally

```bash
npm ci
npm run typecheck
npm run build
npm run test:release
```
