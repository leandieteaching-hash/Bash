# ADR 0003: Authentication and session lifecycle

## Status
Accepted for PR-003.

## Decision
Studio OS delegates password verification, email verification and recovery-token issuance to Supabase Auth. Studio OS maintains a separate revocable session ledger in PostgreSQL. Access and refresh credentials are transported only in secure, HTTP-only, SameSite=Lax cookies.

Refresh credentials are never stored in plaintext. Their SHA-256 digest is stored in `platform_sessions`, rotated after every successful refresh, and compared before the upstream refresh call. A failed refresh revokes the platform session. Password changes revoke every active session for that user.

## Consequences
- Password hashes remain inside the managed identity provider.
- Studio OS can list, audit and revoke individual devices independently.
- API routes must validate both the upstream access token and the platform session record.
- The in-memory rate limiter is an interface-compatible development implementation; distributed deployments must use Redis or an equivalent shared store.
