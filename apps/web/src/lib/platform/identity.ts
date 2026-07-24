import type {SessionIdentity} from '@studio-os/auth';
import {resolveTenant} from '@studio-os/tenancy';
import {createClient} from '@supabase/supabase-js';
import {adminDb} from '@/lib/spread-manager-server';
import {ACCESS_COOKIE, ACTIVE_ORGANISATION_COOKIE, SESSION_COOKIE} from '@/lib/auth/config';
import {readCookie} from '@/lib/auth/cookies';

export type OrganisationSummary = {id:string;slug:string;name:string;locale:string;timezone:string;isDefault:boolean};

export async function readSession(request: Request): Promise<SessionIdentity | null> {
  const accessToken = readCookie(request, ACCESS_COOKIE);
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!accessToken || !sessionId) {
    const developmentUser = process.env.NODE_ENV !== 'production' ? request.headers.get('x-user-id') : null;
    if (!developmentUser) return null;
    return {userId: developmentUser,email:request.headers.get('x-user-email')??'developer@local',organisationId:request.headers.get('x-organisation-id'),sessionId:request.headers.get('x-session-id')??'development-session',expiresAt:new Date(Date.now()+3600000).toISOString()};
  }
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if(!url||!key) throw new Error('AUTH_CONFIGURATION_ERROR');
  const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await client.auth.getUser(accessToken);
  if(error||!data.user)return null;
  const {data:stored,error:sessionError}=await adminDb().from('platform_sessions').select('id,organisation_id,expires_at,revoked_at').eq('id',sessionId).eq('user_id',data.user.id).single();
  if(sessionError||!stored||stored.revoked_at)return null;
  return {userId:data.user.id,email:data.user.email??'',organisationId:readCookie(request,ACTIVE_ORGANISATION_COOKIE)??stored.organisation_id,sessionId:stored.id,expiresAt:stored.expires_at};
}

export async function listOrganisations(userId: string): Promise<OrganisationSummary[]> {
  const {data,error}=await adminDb().from('organisation_members').select('organisation_id,is_default,organisations(id,slug,name,locale,timezone)').eq('user_id',userId).eq('status','active');
  if(error)throw error;
  return (data??[]).flatMap((row:any)=>{const org=Array.isArray(row.organisations)?row.organisations[0]:row.organisations;return org?[{id:org.id,slug:org.slug,name:org.name,locale:org.locale??'en-ZA',timezone:org.timezone??'Africa/Johannesburg',isDefault:Boolean(row.is_default)}]:[]});
}

export async function selectOrganisation(userId:string, requestedId:string):Promise<OrganisationSummary>{
  const organisations=await listOrganisations(userId);const selectedId=resolveTenant({header:requestedId,membershipIds:organisations.map(item=>item.id),defaultId:organisations.find(item=>item.isDefault)?.id});const selected=organisations.find(item=>item.id===selectedId);if(!selected)throw new Error('TENANT_NOT_FOUND');return selected;
}
