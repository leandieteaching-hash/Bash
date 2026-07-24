# Studio OS Application Shell

A cohesive Next.js application shell that integrates the existing transactional Spread Manager package.

## Included

- Complete Dashboard → Books → Book Workspace → Spread Board → Spread Manager navigation.
- All Book Workspace routes: Overview, Spreads, Assets, Characters, Environments, Tasks, Reviews, Approvals, Decisions, Activity, Reports and Settings.
- Responsive desktop, tablet and mobile navigation.
- Shared design tokens and reusable layout components.
- Feature registry and provider extension points.
- Existing RPC-only services, RLS migrations, Realtime collaboration and Playwright workflow tests.

## Start

```bash
npm install
cp tests/e2e/.env.example .env.local
npm run dev
```

Open `http://localhost:3000/dashboard`.

## Verification

```bash
npm run typecheck
npm run test:shell
npm run test:e2e
```

The sample workspace uses `meet-mia`. Replace `src/lib/demo-data.ts` with read-model adapters when the book APIs are connected. Workflow mutations already remain connected through the existing API/RPC boundary.

## Asset Library

The Book Workspace Asset route now contains the Studio OS DAM experience. See `ASSET_LIBRARY.md` and migration `src/db/015_asset_library.sql`.

```bash
npm run test:assets
```

## Reports & Analytics

Interactive Production, Team, Review, Workload, and Executive dashboards are available at `/reports` and inside every Book Workspace. See `REPORTS_ANALYTICS.md`.

## Production operations
The enterprise operations command centre is available at `/admin/system-health`. See `PRODUCTION_OPERATIONS.md` and run `npm run test:operations`.
