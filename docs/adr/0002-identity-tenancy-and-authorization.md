# ADR 0002: Identity, tenancy and authorization boundary

- Status: Accepted
- Date: 2026-07-24

## Context

Studio OS must isolate publishing organisations, support users who belong to more than one organisation, and enforce permissions consistently in PostgreSQL, APIs and user interfaces.

## Decision

Authentication identity remains owned by the configured identity provider (`auth.users` in the Supabase deployment). Studio OS owns user profiles, organisation memberships, sessions, roles and permissions.

Every tenant-owned record carries an `organisation_id`. PostgreSQL Row Level Security is the final isolation boundary. Request transactions set `app.user_id` and `app.organisation_id`; Supabase JWT claims are also supported. Application authorization uses granular permission codes rather than role names.

Refresh tokens, verification tokens and reset tokens are stored only as cryptographic hashes. Sessions are independently revocable and record device and security metadata.

## Consequences

- A user may belong to multiple organisations and selects one active organisation per session.
- API handlers must authenticate, resolve membership and authorize before accessing tenant data.
- Privileged service workers require narrowly scoped database roles and must not bypass tenant filtering accidentally.
- Role hierarchy is supported, but permission evaluation must remain deterministic and cycle-safe through database constraints and administration validation.
