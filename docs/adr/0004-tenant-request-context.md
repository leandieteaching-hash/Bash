# ADR 0004: Authenticated tenant request context

## Status
Accepted

## Decision
Every tenant-aware request derives its organisation from a validated Studio OS session and active organisation membership. Client-provided organisation headers are not an authorization source. The selected organisation is persisted in both an HTTP-only cookie and the revocable platform session ledger.

Tenant-sensitive database operations use transaction-scoped PostgreSQL context through RPC functions. This is necessary because pooled Supabase connections cannot safely retain `set_config` state between separate HTTP calls.

## Consequences
- Organization switching is membership checked and auditable.
- RLS policies compare rows with the transaction's organization context.
- Cross-tenant access fails even when identifiers are guessed.
- New tenant-owned tables must include `organisation_id` and isolation tests.
