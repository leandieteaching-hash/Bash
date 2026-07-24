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

## Development setup

```bash
cp .env.example .env
npm ci
npm run dev:services
npm run dev
```

Mailpit is available at `http://localhost:8025`. Run `npm run verify` before opening a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) and [ADR 0001](docs/adr/0001-monorepo-and-tooling.md).
