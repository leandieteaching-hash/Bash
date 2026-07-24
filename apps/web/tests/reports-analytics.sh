#!/usr/bin/env bash
set -euo pipefail
required=("src/features/reports/ReportsDashboard.tsx" "src/app/api/reports/export/route.ts" "src/app/api/reports/schedules/route.ts" "../../database/migrations/016_reports_analytics.sql")
for file in "${required[@]}"; do test -f "$file" || { echo "Missing $file"; exit 1; }; done
grep -q "Production dashboard" src/features/reports/demo-reports.ts
grep -q "Executive dashboard" src/features/reports/demo-reports.ts
grep -q "Export CSV" src/features/reports/ReportsDashboard.tsx
grep -q "Schedule" src/features/reports/ReportsDashboard.tsx
echo "Reports & Analytics structural checks passed."
