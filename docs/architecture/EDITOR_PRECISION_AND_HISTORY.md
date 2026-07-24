# Editor precision and history

## Precision tools
The visual editor supports eight resize handles, numeric position and size controls, rotation, 1-point keyboard nudging, 10-point Shift nudging, zoom from 25% to 200%, grid snapping, rulers, bleed guides, margin guides and centre guides.

Canvas geometry is stored in print points. Zoom is a view transform, ensuring exports and collaboration use stable coordinates.

## Undo and redo
The browser keeps a bounded local history of the last 50 document states. Undo and redo trigger the same debounced persistence path as direct edits and therefore retain optimistic concurrency protection.

## Revision history
Every successful save snapshots the previous document state. Users with `spreads.editor.history` can list revisions. Users with `spreads.editor.history.restore` can restore one. Restoration is atomic, checks the expected current version, snapshots the pre-restore state, and emits an audit event.

## Asset placement
The Asset Library picker searches assets within the active book and tenant. Placed image elements retain asset and asset-version identifiers, allowing later validation, replacement and usage tracking.
