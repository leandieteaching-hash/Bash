export type PlatformServiceStatus='operational'|'degraded'|'outage';
export type FoundationMetric={label:string;value:string;detail:string;status?:PlatformServiceStatus};
export type TenantSummary={id:string;name:string;region:string;plan:string;users:number;status:'active'|'trial'|'suspended'};
export type AuditEntry={id:string;actor:string;action:string;resource:string;occurredAt:string;tenant:string};
