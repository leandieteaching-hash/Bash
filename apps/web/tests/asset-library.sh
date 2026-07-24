#!/usr/bin/env bash
set -euo pipefail
need=(
 "src/features/assets/AssetLibrary.tsx"
 "src/features/assets/asset-service.ts"
 "src/features/assets/types.ts"
 "src/features/assets/AssetLibrary.module.css"
 "../../database/migrations/015_asset_library.sql"
 "src/app/api/assets/upload-url/route.ts"
 "src/app/api/assets/finalize/route.ts"
 "src/app/api/assets/bulk/route.ts"
 "src/app/api/assets/search/route.ts"
 "../../docs/architecture/ASSET_LIBRARY.md"
)
for f in "${need[@]}"; do test -f "$f" || { echo "Missing $f"; exit 1; }; done
grep -q 'workflow_finalize_asset_upload' ../../database/migrations/015_asset_library.sql
grep -q 'workflow_bulk_update_assets' ../../database/migrations/015_asset_library.sql
grep -q 'AssetLibrary' src/app/books/'[bookId]'/assets/page.tsx
! grep -R "router.refresh\|location.reload" src/features/assets
echo "Asset Library structure verified."
