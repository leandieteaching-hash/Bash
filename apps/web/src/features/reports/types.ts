export type DashboardKind = 'production' | 'team' | 'review' | 'workload' | 'executive';
export type DateRange = '30d' | '90d' | '6m' | '12m';
export interface ReportFilters { bookId?: string; dateRange: DateRange; team?: string; status?: string; }
export interface Metric { label: string; value: string; change?: string; tone?: 'positive'|'warning'|'neutral'; }
export interface SeriesPoint { label: string; value: number; secondary?: number; }
export interface DashboardData {
  kind: DashboardKind;
  title: string;
  description: string;
  metrics: Metric[];
  trend: SeriesPoint[];
  breakdown: SeriesPoint[];
  rows: Array<Record<string,string|number>>;
}
export interface ReportSchedule { id: string; name: string; dashboard: DashboardKind; cadence: 'daily'|'weekly'|'monthly'; deliveryTime: string; recipients: string[]; format: 'csv'|'pdf'; enabled: boolean; }
