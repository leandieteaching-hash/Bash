# Visual Spread Editor

The editor is a tenant-scoped composition surface for text, images and shapes. Coordinates and dimensions are stored in points, preserving print-oriented measurements while allowing responsive screen scaling.

## Boundaries
- `spread_documents` owns canvas settings and current element JSON.
- `spread_document_revisions` stores immutable previous versions.
- Asset elements reference Asset Library identifiers and immutable asset-version identifiers.
- API access requires `spreads.editor.read` or `spreads.editor.update`.
- Organization context comes from the authenticated Studio OS session.

## Save lifecycle
The client debounces edits, sends its expected version, and receives the incremented version. PostgreSQL locks the document, verifies the expected version, snapshots the current content, writes the replacement, and emits audit/outbox records through the service layer. A stale client receives `409 VERSION_CONFLICT`.

## Interaction foundation
PR-011 includes element selection, drag movement, canvas bounds, grid snapping, text and shape creation, asset placement, deletion, an inspector, responsive layout and autosave status. Resize handles, zoom, page guides, keyboard nudging, undo/redo and collaborative cursors are natural follow-on work.
