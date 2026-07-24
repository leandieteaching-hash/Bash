# Studio OS Reports & Analytics

The Reports feature is integrated into both `/reports` and `/books/[bookId]/reports`.

## Dashboards

- Production: progress, risk, delivery forecasts and spread status.
- Team: throughput, overdue work and collaboration performance.
- Review: turnaround, first-pass approval and required changes.
- Workload: capacity, allocation and due work.
- Executive: portfolio completion, forecast confidence, quality and variance.

## Shared capabilities

All dashboards use the same filters, metric cards, trend and breakdown charts, detail tables, CSV export, server-generated PDF export, and scheduling modal.

## Integration boundary

`POST /api/reports/data` is the read-model adapter. Replace demonstration data with the SQL reporting views or materialized views without changing dashboard components.

`GET /api/reports/export` creates a PDF response. In production it can be replaced with a branded renderer and private Storage persistence.

`POST /api/reports/schedules` validates scheduled-report definitions. Connect it to `report_schedules` through an authenticated RPC and execute due schedules from a trusted worker or Supabase scheduled function.

## Security

Use portfolio and book report permissions at the API boundary. RLS protects schedules by owner. Report workers should use a service role and record each execution in `report_runs`.
