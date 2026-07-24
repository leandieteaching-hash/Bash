# ADR 0013: Review comments and canvas annotations

## Decision
Studio OS stores review cycles, assignments, canvas annotations and threaded comments as tenant-owned records. An annotation may target a spread coordinate, a canvas element, or a rectangular region. Comments are append-oriented, with edit history retained separately.

## Security
Every API derives the organisation from the authenticated session and evaluates RBAC before data access. PostgreSQL RLS is an additional tenant boundary. Mentions are identifiers only; notification delivery consumes outbox events asynchronously.

## Lifecycle
Annotations move through open, in discussion, resolved, verified and closed states. Reopening clears resolution metadata. Completing a review cycle is intentionally separate from resolving individual annotations.

## Consequences
Review history remains auditable and can support external reviewers, notification channels and approval gates without changing the visual editor document format.
