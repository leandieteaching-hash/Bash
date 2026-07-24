BEGIN;

ALTER TABLE review_requests
    ADD COLUMN IF NOT EXISTS completed_at timestamptz;

ALTER TABLE review_comments
    ADD COLUMN IF NOT EXISTS resolved_by uuid REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS resolved_at timestamptz;

ALTER TABLE approvals
    ADD COLUMN IF NOT EXISTS revoked_by uuid REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_assets_spread_active
    ON assets (spread_id, created_at)
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_asset_versions_asset_version_desc
    ON asset_versions (asset_id, version_number DESC);

CREATE INDEX IF NOT EXISTS idx_review_requests_asset_version_status
    ON review_requests (asset_version_id, status);

CREATE INDEX IF NOT EXISTS idx_review_comments_review_unresolved
    ON review_comments (review_id, severity)
    WHERE is_resolved = false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_asset_versions_asset_version_number
    ON asset_versions (asset_id, version_number);

CREATE UNIQUE INDEX IF NOT EXISTS uq_asset_versions_one_current
    ON asset_versions (asset_id)
    WHERE is_current = true;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_asset_version_approval
    ON approvals (entity_id, asset_version_id, approval_type)
    WHERE entity_type = 'Asset'
      AND decision = 'Approved'
      AND revoked_at IS NULL;

COMMIT;
