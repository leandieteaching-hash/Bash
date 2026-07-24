export type Permission = `${string}.${string}`;
export type PolicyEffect = 'allow' | 'deny';
export type PolicyDecision = {allowed:boolean;permission:Permission;reason:string;matchedBy?:string};
export type RoleGrant = {code:string;permissions:ReadonlySet<string>;parent?:RoleGrant|null};
export type AuthorizationContext = {permissions:ReadonlySet<string>;roles?:ReadonlyArray<RoleGrant>;deniedPermissions?:ReadonlySet<string>};

export function collectPermissions(roles:ReadonlyArray<RoleGrant> = []):Set<string>{
  const result=new Set<string>();
  const visit=(role:RoleGrant|undefined|null,seen:Set<string>)=>{if(!role||seen.has(role.code))return;seen.add(role.code);role.permissions.forEach(p=>result.add(p));visit(role.parent,seen)};
  roles.forEach(role=>visit(role,new Set()));return result;
}
export function decide(context:AuthorizationContext, permission:Permission):PolicyDecision{
  if(context.deniedPermissions?.has(permission))return {allowed:false,permission,reason:'explicit-deny'};
  const inherited=collectPermissions(context.roles);const direct=context.permissions;
  if(direct.has('platform.admin')||inherited.has('platform.admin'))return {allowed:true,permission,reason:'platform-admin',matchedBy:'platform.admin'};
  if(direct.has(permission))return {allowed:true,permission,reason:'direct-permission',matchedBy:permission};
  if(inherited.has(permission))return {allowed:true,permission,reason:'inherited-role',matchedBy:permission};
  return {allowed:false,permission,reason:'missing-permission'};
}
export function can(context:AuthorizationContext, permission:Permission):boolean{return decide(context,permission).allowed}
export class AuthorizationError extends Error{constructor(public permission:Permission,public decision:PolicyDecision){super(`FORBIDDEN:${permission}`);this.name='AuthorizationError'}}
export function authorize(context:AuthorizationContext, permission:Permission):void{const decision=decide(context,permission);if(!decision.allowed)throw new AuthorizationError(permission,decision)}
