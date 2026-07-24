# Security Review Record

## Threat boundaries reviewed

- Authentication cookies and refresh-token rotation
- Tenant-context derivation and PostgreSQL RLS
- RBAC evaluation and administrative mutation routes
- Asset and editor document access
- Review and approval evidence
- Audit/outbox data exposure
- Deployment credentials and database backups

## Required automated gates

- secret scanning across full Git history;
- static high-risk-pattern review;
- `npm audit --audit-level=high` from the committed lockfile;
- dependency update review;
- runtime security-header checks;
- authenticated cross-tenant integration tests;
- DAST against staging using an approved scanner.

## Manual penetration-test scope

Test authentication bypass, session fixation, token replay, CSRF, IDOR/cross-tenant access, privilege escalation, mass assignment, stored/reflected XSS, SQL injection, SSRF, unsafe file upload, rate-limit bypass, audit tampering and approval forgery. Findings must include evidence, severity, owner, remediation and retest status.

This repository review is not a substitute for an independent penetration test against a deployed staging environment.
