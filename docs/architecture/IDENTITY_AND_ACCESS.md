# Identity and Access Foundation

## Request boundary

1. Authenticate the session.
2. Resolve the requested organisation from an explicit trusted session value.
3. Verify active membership.
4. set `app.user_id` and `app.organisation_id` inside the database transaction.
5. Evaluate granular permissions.
6. execute the use case and append audit/outbox records in the same transaction.

Development-only headers currently exercise the API contract. They are adapters, not the production authentication mechanism, and will be replaced by signed session cookies in the authentication implementation PR.

## Core permissions

Permissions use `<resource>.<action>` codes such as `identity.members.manage` and `tenant.switch`. Roles are organisation-scoped or system-owned bundles of permissions. APIs must never authorize by UI visibility or role display name.

## Token handling

Raw refresh, password-reset and email-verification tokens are returned only at issuance. PostgreSQL stores hashes. Tokens are single-use, expire, and can be revoked through session or account security workflows.
