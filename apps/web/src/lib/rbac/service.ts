import {adminDb} from '@/lib/spread-manager-server';
import type {SessionIdentity} from '@studio-os/auth';

export async function effectivePermissions(identity:SessionIdentity):Promise<Set<string>>{
 if(!identity.organisationId)return new Set();
 const {data,error}=await adminDb().rpc('effective_permissions',{target_user_id:identity.userId,target_organisation_id:identity.organisationId});
 if(error)throw error;return new Set((data??[]).map((row:{permission_code:string})=>row.permission_code));
}
export async function requirePermission(identity:SessionIdentity,permission:string){const permissions=await effectivePermissions(identity);if(!permissions.has(permission)&&!permissions.has('platform.admin'))throw new Error(`FORBIDDEN:${permission}`)}
export async function listMatrix(organisationId:string){
 const db=adminDb();
 const [{data:roles,error:roleError},{data:permissions,error:permissionError}]=await Promise.all([
  db.from('platform_roles').select('id,code,name,description,parent_role_id,is_system,status,version').or(`organisation_id.eq.${organisationId},organisation_id.is.null`).order('name'),
  db.from('platform_permissions').select('code,description').order('code')]);
 if(roleError||permissionError)throw roleError??permissionError;
 const roleIds=(roles??[]).map(role=>role.id);
 const {data:grants,error:grantError}=roleIds.length
  ? await db.from('platform_role_permissions').select('role_id,permission_code').in('role_id',roleIds)
  : {data:[],error:null};
 if(grantError)throw grantError;
 return {roles:roles??[],permissions:permissions??[],grants:grants??[]};
}
export async function replaceRolePermissions(identity:SessionIdentity,roleId:string,codes:string[],requestId:string){await requirePermission(identity,'identity.roles.manage');const {error}=await adminDb().rpc('replace_role_permissions',{target_role_id:roleId,permission_codes:codes});if(error)throw error;await adminDb().from('platform_audit_events').insert({organisation_id:identity.organisationId,request_id:requestId,actor_id:identity.userId,action:'rbac.role_permissions.replaced',resource_type:'platform_role',resource_id:roleId,metadata:{permissionCodes:codes}})}
