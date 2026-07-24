export type HealthState='healthy'|'warning'|'critical'|'unknown';
export type ServiceHealth={id:string;name:string;state:HealthState;latencyMs:number;uptime:number;lastChecked:string;detail:string};
export type Incident={id:string;severity:'info'|'warning'|'critical';title:string;status:'open'|'acknowledged'|'resolved';startedAt:string;owner?:string};
export type OperationsSnapshot={generatedAt:string;services:ServiceHealth[];metrics:{apiP95Ms:number;errorRate:number;queueDepth:number;storageUsedGb:number;backupAgeHours:number;activeUsers:number};incidents:Incident[]};
