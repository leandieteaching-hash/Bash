#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
test -f "$ROOT/database/migrations/025_editor_precision_and_history.sql"
grep -q "restore_spread_document_revision" "$ROOT/database/migrations/025_editor_precision_and_history.sql"
grep -q "spreads.editor.history.restore" "$ROOT/database/migrations/025_editor_precision_and_history.sql"
grep -q "resizeElement" "$ROOT/apps/web/src/features/spread-editor/editor-model.ts"
grep -q "nudgeElement" "$ROOT/apps/web/src/features/spread-editor/editor-model.ts"
grep -q "Revision history" "$ROOT/apps/web/src/features/spread-editor/VisualSpreadEditor.tsx"
grep -q "Asset Library" "$ROOT/apps/web/src/features/spread-editor/VisualSpreadEditor.tsx"
grep -q "Undo" "$ROOT/apps/web/src/features/spread-editor/VisualSpreadEditor.tsx"
test -f "$ROOT/apps/web/src/app/api/v1/spreads/[spreadId]/document/revisions/route.ts"
test -f "$ROOT/apps/web/src/app/api/v1/spreads/[spreadId]/document/revisions/[revisionId]/restore/route.ts"
echo "Editor precision and history checks passed."
