# ADR 0009: Book Management aggregate

## Status
Accepted

## Decision
A book is the tenant-scoped publication aggregate root. Editions, hierarchical sections, contributors and milestones belong to a book and repeat the organisation identifier to support explicit RLS enforcement and efficient tenant filtering.

Book creation is performed by a database function that atomically creates the book and its first edition. Updates use an integer version for optimistic concurrency. Binary cover and content assets remain owned by the Asset Library and are referenced by identifier rather than duplicated.

## Consequences
- All book reads and writes require active tenant context and granular RBAC permissions.
- Domain events and audit records are emitted for mutations.
- Section ordering is deterministic within each parent.
- Future spread, translation, rights and publishing modules attach to stable book and edition identifiers.
