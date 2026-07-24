# ADR 0012: Editor precision tools and history

## Status
Accepted

## Decision
Studio OS will keep precision transformations in the client document model while persisting immutable server-side revisions through optimistic concurrency. Undo and redo are local command-history operations; saved revision restoration is a server-authorized, audited transaction.

The canvas uses print points as its canonical unit. Zoom changes presentation only and never mutates persisted coordinates. Asset placement references an Asset Library record and immutable version when available.

## Consequences
- Keyboard and pointer operations produce the same document shape.
- Revision restore cannot bypass tenant or RBAC boundaries.
- A restore creates a snapshot of the current state before replacing content.
- Real-time co-editing remains deferred; version conflicts are explicit.
