# Mutation contract

Implement these routes using the service patterns in `service.ts`:

- `POST /api/v1/assets`
  - permission: `asset.create`
  - creates a logical asset for the spread

- `POST /api/v1/assets/{assetId}/upload-url`
  - permission: `asset.upload`
  - returns a short-lived Supabase signed upload URL

- `POST /api/v1/assets/{assetId}/versions`
  - permission: `asset.upload`
  - verifies storage path, increments version number, marks current version, logs activity

- `POST /api/v1/review-requests`
  - permission: `review.request`
  - validates spread/asset/version ownership and active reviewer

- `POST /api/v1/review-requests/{id}/complete`
  - permission: `review.complete`
  - creates review and review comments; changes asset status

- `POST /api/v1/assets/{assetId}/versions/{versionId}/approve`
  - permission: `asset.approve`
  - blocks approval while required-change comments remain unresolved

- `POST /api/v1/approvals/{approvalId}/revoke`
  - permission: `asset.approve`
  - preserves approval history and returns asset to Changes Requested

All mutation endpoints must create `activity_events` records and must never overwrite version files.


## Spread production context

- `POST /api/v1/spreads/{spreadId}/characters` — `spread.edit`
- `DELETE /api/v1/spreads/{spreadId}/characters/{appearanceId}` — `spread.edit`
- `POST /api/v1/spreads/{spreadId}/tasks` — `task.create`
- `PATCH /api/v1/spreads/{spreadId}/tasks/{taskId}` — `task.edit`
- `POST /api/v1/spreads/{spreadId}/decisions` — `decision.create`
- `POST /api/v1/spreads/{spreadId}/decisions/{decisionId}/approve` — `decision.approve`
