# Authentication

## Login
`POST /api/v1/auth/login` validates input, applies throttling, authenticates with Supabase Auth, resolves the user's default active organisation, creates a `platform_sessions` row and sets HTTP-only access, refresh, session and organisation cookies.

## Refresh
`POST /api/v1/auth/refresh` requires the refresh cookie and platform-session cookie. The stored refresh digest must match, the session must not be revoked, and its absolute lifetime must not have elapsed. Successful refresh rotates the digest and increments `rotation_counter`.

## Logout
`POST /api/v1/auth/logout` revokes the platform session and expires every authentication cookie.

## Recovery and verification
Password-reset and email-verification requests always return accepted responses to avoid account enumeration. Password changes revoke all active sessions. Recovery links terminate at `/reset-password`.

## Production requirements
Replace the process-local rate limiter with a shared Redis-backed implementation before horizontal scaling. Configure Supabase redirect allowlists, SMTP delivery, leaked-password protection and MFA policies in each environment.
