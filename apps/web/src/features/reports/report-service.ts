import type {DashboardData,DashboardKind,ReportFilters,ReportSchedule} from './types';
import {getDemoDashboard} from './demo-reports';
export async function loadDashboard(kind:DashboardKind,filters:ReportFilters):Promise<DashboardData>{
  try { const response=await fetch('/api/reports/data',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({kind,filters})}); if(response.ok)return response.json(); } catch {}
  return getDemoDashboard(kind);
}
export async function saveSchedule(schedule:Omit<ReportSchedule,'id'>){const response=await fetch('/api/reports/schedules',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(schedule)});if(!response.ok)throw new Error('Unable to save schedule');return response.json();}
