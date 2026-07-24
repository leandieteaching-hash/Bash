#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
test -f "$ROOT/database/migrations/024_visual_spread_editor.sql"
grep -q "save_spread_document" "$ROOT/database/migrations/024_visual_spread_editor.sql"
grep -q "VERSION_CONFLICT" "$ROOT/database/migrations/024_visual_spread_editor.sql"
grep -q "spreads.editor.update" "$ROOT/database/migrations/024_visual_spread_editor.sql"
test -f "$ROOT/apps/web/src/features/spread-editor/VisualSpreadEditor.tsx"
grep -q "Editor autosave" "$ROOT/apps/web/src/features/spread-editor/VisualSpreadEditor.tsx"
grep -q "placeAsset" "$ROOT/apps/web/src/features/spread-editor/editor-model.ts"
test -f "$ROOT/apps/web/src/app/api/v1/spreads/[spreadId]/document/route.ts"
test -f "$ROOT/apps/web/src/app/books/[bookId]/spreads/[spreadId]/editor/page.tsx"
echo "Visual Spread Editor checks passed."
