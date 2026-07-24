import type {RequestContext} from './context';
export type AuditRecord={id:string;requestId:string;tenantId:string;actorId:string;action:string;resourceType:string;resourceId:string;metadata:Record<string,unknown>;occurredAt:string};
const records:AuditRecord[]=[];
export function writeAudit(context:RequestContext,input:Omit<AuditRecord,'id'|'requestId'|'tenantId'|'actorId'|'occurredAt'>){const record={...input,id:crypto.randomUUID(),requestId:context.requestId,tenantId:context.tenantId,actorId:context.userId,occurredAt:new Date().toISOString()};records.unshift(record);return record}
export function listAudit(tenantId:string){return records.filter(r=>r.tenantId===tenantId).slice(0,100)}
