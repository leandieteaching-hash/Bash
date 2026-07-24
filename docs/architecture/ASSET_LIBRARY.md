# Studio OS Asset Library

The Asset Library is the shared DAM module for book production. It is mounted at `/books/[bookId]/assets` and uses the Application Shell's Book Workspace, providers, permissions and responsive layout.

## Product surface

- Grid and list views
- Full-text search, type/status filters and collection browsing
- Drag-and-drop multi-file upload queue
- Immutable asset versions and current-version history
- Editable metadata and tags
- Selection and bulk tagging, collection assignment and archival
- Collection cards
- Asset usage tracking across spreads, characters, environments and exports
- Relationships: variant, derivative, reference and companion
- Storage lifecycle status: active, archived, cold storage and scheduled deletion
- Responsive inspector drawer

The included UI starts with demonstration read data so the package runs without a configured Supabase project. The `asset-service.ts` adapter and API routes are the production integration boundary.

## Upload transaction

1. `POST /api/assets/upload-url` requests a signed Supabase Storage upload URL.
2. The browser uploads directly to the private `studio-assets` bucket.
3. `POST /api/assets/finalize` calls `workflow_finalize_asset_upload`.
4. PostgreSQL creates or locks the asset, allocates the next immutable version, marks it current, attaches tags and writes activity.
5. A storage worker creates derivatives and updates `thumbnail_storage_path` and `technical_metadata`.

Never expose the service-role key to the browser. Original uploads should be private; deliver previews with short-lived signed URLs.

## Thumbnail worker contract

Trigger on `asset_versions` insert or Storage object creation. The worker should:

- validate MIME type and magic bytes
- virus scan the original
- calculate SHA-256 checksum
- extract width, height, colour profile and page count
- create web preview and thumbnail derivatives
- preserve alpha where applicable
- update `technical_metadata`, checksum and thumbnail path
- emit a notification event on failure

PSD/TIFF/PDF processing should run outside request handlers in a bounded worker.

## Lifecycle defaults

- Current versions: active storage
- Superseded versions: eligible for cold storage after 90 days
- Archived assets: retained while referenced by usage or release records
- Scheduled deletion: two-person approval plus retention window
- Released/exported assets: legal hold until release retention expires

Object deletion must only occur after the database workflow verifies that no active usage, approval, release or legal hold blocks removal.

## Permissions

- `asset.view`
- `asset.upload`
- `asset.edit`
- `asset.archive`
- `asset.delete`
- `asset.manage_collections`
- `asset.manage_relationships`
- `asset.view_original`

## Realtime

Publish `assets`, `asset_versions`, `asset_tags`, `asset_collection_items`, `asset_usage` and `asset_relationships` to `supabase_realtime`. Subscribe by book and silently merge changed records into the current query cache without resetting selection, filters or the inspector.
