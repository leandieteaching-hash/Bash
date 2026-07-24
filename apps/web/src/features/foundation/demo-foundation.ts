import type {AuditEntry,FoundationMetric,TenantSummary} from './types';
export const metrics:FoundationMetric[]=[
 {label:'Platform availability',value:'99.98%',detail:'Rolling 30 days',status:'operational'},
 {label:'Active tenants',value:'12',detail:'10 production · 2 pilot'},
 {label:'API p95 latency',value:'184 ms',detail:'Target < 300 ms',status:'operational'},
 {label:'Open security findings',value:'0',detail:'Critical or high severity',status:'operational'}
];
export const tenants:TenantSummary[]=[
 {id:'tenant-foundation-first',name:'Foundation First Publishing',region:'af-south-1',plan:'Enterprise Pilot',users:38,status:'active'},
 {id:'tenant-demo',name:'Studio OS Demonstration',region:'eu-west-1',plan:'Internal',users:12,status:'active'}
];
export const auditEntries:AuditEntry[]=[
 {id:'evt-1042',actor:'Leandie Jacobs',action:'role.assigned',resource:'Production Editor',occurredAt:'2026-07-24 10:42',tenant:'Foundation First Publishing'},
 {id:'evt-1041',actor:'System',action:'backup.verified',resource:'postgres-primary',occurredAt:'2026-07-24 09:30',tenant:'Platform'},
 {id:'evt-1040',actor:'Release Bot',action:'deployment.completed',resource:'v1.0.0-rc.1',occurredAt:'2026-07-24 08:15',tenant:'Platform'}
];
export const services=[
 ['Identity & SSO','Operational','OIDC and session validation'],['Tenant isolation','Operational','RLS policy verification passed'],['Event bus','Operational','0 messages in dead-letter queue'],['Audit pipeline','Operational','Last event 18 seconds ago'],['Object storage','Operational','All configured regions available'],['Observability','Operational','Metrics, logs and traces reporting']
] as const;
