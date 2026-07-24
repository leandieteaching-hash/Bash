#!/usr/bin/env bash
set -euo pipefail
required=(
"src/app/layout.tsx" "src/components/layout/AppShell.tsx" "src/components/workspace/BookWorkspace.tsx"
"src/features/registry.ts" "src/app/dashboard/page.tsx" "src/app/books/page.tsx"
"src/app/books/[bookId]/overview/page.tsx" "src/app/books/[bookId]/spreads/page.tsx"
"src/app/books/[bookId]/spreads/[spreadId]/manager/page.tsx"
)
for f in "${required[@]}"; do test -f "$f" || { echo "Missing $f"; exit 1; }; done
for section in overview spreads assets characters environments tasks reviews approvals decisions activity reports settings; do test -f "src/app/books/[bookId]/$section/page.tsx" || { echo "Missing workspace route $section"; exit 1; }; done
grep -R "SpreadManager" -n 'src/app/books/[bookId]/spreads/[spreadId]/manager/page.tsx' >/dev/null
echo "Application shell structure verified."
