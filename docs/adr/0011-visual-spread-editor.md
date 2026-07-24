# ADR 0011: Visual spread editor document model

## Decision
Store each spread's editable composition as a versioned JSON document in PostgreSQL. Binary assets remain in the Asset Library and canvas elements reference immutable asset versions. Saves use optimistic concurrency through `save_spread_document`; every accepted save snapshots the prior revision.

## Consequences
The editor can autosave without replacing the publishing-domain spread record. Rendering engines can evolve independently. Concurrent edits receive an explicit version conflict rather than silently overwriting work. Real-time collaborative operations are deferred to a later change and can layer on top of the revision model.
