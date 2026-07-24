# Studio OS Platform Foundation v1.0.0

Release 1 establishes the production boundary for every Studio OS business module.

## Included

- Tenant-aware application and API request context
- Organisation, membership, roles and permission schema
- PostgreSQL Row Level Security boundary
- Versioned REST platform endpoints
- Domain event contract and transactional outbox schema
- Immutable audit event schema
- API-key storage model using hashes rather than plaintext secrets
- Application shell and feature registry integration
- Versioned design tokens and component reference screen
- Health, metrics, logging, backups, deployment and security scanning inherited from Production Operations

## Routes

- `/admin/platform` — foundation command centre
- `/design-system` — component and token reference
- `/admin/system-health` — operational health
- `/api/v1/platform/status` — service readiness
- `/api/v1/platform/events` — authorized domain event publishing
- `/api/v1/platform/audit` — tenant-scoped audit access

## Security model

Every request resolves a request ID, tenant ID, user ID and role set. Production deployments must replace the demonstration headers with verified claims from the configured OIDC/SAML identity provider. Database RLS remains the final enforcement boundary.

## Production acceptance

1. Apply migrations through `018_platform_foundation.sql`.
2. Configure Supabase/PostgreSQL and object storage secrets.
3. Replace demo header context with verified session claims.
4. Run `npm run test:foundation`, `npm run typecheck`, and `npm run build`.
5. Validate backup restoration and deployment smoke tests.
