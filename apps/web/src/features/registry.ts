import type { ComponentType } from 'react';
export type FeatureRegistration={id:string;label:string;scope:'global'|'book'|'spread';route:string;permission?:string;description:string;load?:()=>Promise<{default:ComponentType<any>}>};
export const featureRegistry:FeatureRegistration[]=[
{id:'assets',label:'Assets',scope:'book',route:'assets',permission:'asset.view',description:'Digital asset management and immutable versions.'},
{id:'notifications',label:'Notifications',scope:'global',route:'/notifications',permission:'notification.view',description:'Realtime work assignments and digests.'},
{id:'reports',label:'Reports',scope:'book',route:'reports',permission:'report.view_book',description:'Production, workload and audit analytics.'},
{id:'foundation',label:'Platform Foundation',scope:'global',route:'/admin/platform',permission:'platform.admin',description:'Identity, tenancy, access, APIs, events and audit controls.'},
{id:'operations',label:'System Health',scope:'global',route:'/admin/system-health',permission:'system.health.view',description:'Monitoring, recovery, deployment and security operations.'},
{id:'spread-manager',label:'Spread Manager',scope:'spread',route:'manager',permission:'spread.view',description:'Transactional spread production workspace.',load:()=>import('./spread-manager/SpreadManager').then(m=>({default:m.SpreadManager}))}
];
