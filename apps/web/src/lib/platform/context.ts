export type RequestContext={requestId:string;tenantId:string;userId:string;roles:string[]};
export function getRequestContext(request:Request):RequestContext{
 const requestId=request.headers.get('x-request-id')??crypto.randomUUID();
 return {requestId,tenantId:request.headers.get('x-organisation-id')??request.headers.get('x-tenant-id')??'11111111-1111-4111-8111-111111111111',userId:request.headers.get('x-user-id')??'demo-user',roles:(request.headers.get('x-roles')??'platform_admin').split(',').map(v=>v.trim())};
}
export function requireRole(context:RequestContext,allowed:string[]){if(!context.roles.some(role=>allowed.includes(role)))throw new Error('FORBIDDEN')}
