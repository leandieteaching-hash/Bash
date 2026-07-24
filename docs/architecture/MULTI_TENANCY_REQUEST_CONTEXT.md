# Multi-tenancy request context

Studio OS resolves tenancy in this order: authenticated session, active membership validation, default membership fallback. Request headers may carry correlation data but never choose an organization in production.

`getTenantContext` returns the organization, user, session, locale, timezone and request ID. Tenant-sensitive SQL is executed through RPC functions that call `set_request_context` and query within the same PostgreSQL transaction. This avoids connection-pool context leakage.

Organization switching validates membership, updates `platform_sessions.organisation_id`, sets the HTTP-only active-organization cookie and writes `tenant.switched` to the audit stream.

Every tenant-owned table must:
1. contain a non-null `organisation_id`;
2. enable RLS;
3. compare `organisation_id` to `current_organisation_id()`;
4. verify active membership;
5. include a negative cross-tenant test.
