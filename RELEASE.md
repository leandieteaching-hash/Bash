# Release policy

Studio OS releases are created only by the tag-triggered GitHub Actions workflow.

A baseline tag may be created only after all of the following pass from a clean checkout:

```bash
npm ci
npm run typecheck
npm run build
npm run test:release
```

Use `scripts/tag-verified-baseline.sh` to enforce these gates locally. The release workflow produces the source ZIP and container image; developers do not publish hand-built release artifacts.

## PR-004 — Multi-tenancy request context

- Authenticated tenant request context and organization metadata.
- Membership-safe organization switching persisted to cookie and session ledger.
- Transaction-scoped PostgreSQL context RPCs for pooled connections.
- RLS hardening for platform audit and event-outbox records.
- Organization switcher in the application shell.
- Tenant context and settings APIs plus isolation verification gate.
