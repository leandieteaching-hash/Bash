#!/usr/bin/env bash
set -euo pipefail
grep -q 'Skip to main content' apps/web/src/components/accessibility/SkipLink.tsx
grep -q 'prefers-reduced-motion' apps/web/src/app/globals.css
grep -q 'focus-visible' apps/web/src/app/globals.css
grep -q 'id="main-content"' apps/web/src/components/layout/AppShell.tsx || grep -q 'id="main-content"' apps/web/src/components/layout/Page.tsx
