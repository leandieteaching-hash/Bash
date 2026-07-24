import {createClient} from '@supabase/supabase-js';
import {adminDb} from '@/lib/spread-manager-server';
import {hashSecret} from './crypto';
import {authDurations} from './config';

function authClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error('AUTH_CONFIGURATION_ERROR');
  return createClient(url, key, {auth: {persistSession: false, autoRefreshToken: false}});
}

export type LoginInput = {email: string; password: string; rememberMe: boolean; request: Request};

export async function loginWithPassword(input: LoginInput) {
  const client = authClient();
  const {data, error} = await client.auth.signInWithPassword({email: input.email, password: input.password});
  if (error || !data.user || !data.session) throw new Error('INVALID_CREDENTIALS');
  const db = adminDb();
  const {data: memberships, error: membershipError} = await db
    .from('organisation_members')
    .select('organisation_id,is_default,status')
    .eq('user_id', data.user.id)
    .eq('status', 'active')
    .order('is_default', {ascending: false});
  if (membershipError) throw membershipError;
  const organisationId = memberships?.[0]?.organisation_id ?? null;
  const seconds = input.rememberMe ? authDurations.rememberedSessionSeconds : authDurations.sessionSeconds;
  const expiresAt = new Date(Date.now() + seconds * 1000).toISOString();
  const {data: stored, error: sessionError} = await db.from('platform_sessions').insert({
    user_id: data.user.id,
    organisation_id: organisationId,
    refresh_token_hash: hashSecret(data.session.refresh_token),
    access_token_hash: hashSecret(data.session.access_token),
    device_name: input.request.headers.get('sec-ch-ua-platform') ?? 'Unknown device',
    ip_address: input.request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || null,
    user_agent: input.request.headers.get('user-agent'),
    remember_me: input.rememberMe,
    expires_at: expiresAt,
    absolute_expires_at: expiresAt,
  }).select('id').single();
  if (sessionError || !stored) throw sessionError ?? new Error('SESSION_CREATE_FAILED');
  await db.from('platform_user_profiles').update({last_login_at: new Date().toISOString()}).eq('user_id', data.user.id);
  return {user: data.user, authSession: data.session, platformSessionId: stored.id, organisationId, expiresAt};
}

export async function rotateRefreshToken(refreshToken: string, platformSessionId: string) {
  const db = adminDb();
  const {data: stored, error: lookupError} = await db.from('platform_sessions').select('*').eq('id', platformSessionId).is('revoked_at', null).single();
  if (lookupError || !stored || stored.refresh_token_hash !== hashSecret(refreshToken)) throw new Error('INVALID_REFRESH_TOKEN');
  if (Date.parse(stored.absolute_expires_at ?? stored.expires_at) <= Date.now()) throw new Error('SESSION_EXPIRED');
  const client = authClient();
  const {data, error} = await client.auth.refreshSession({refresh_token: refreshToken});
  if (error || !data.session || !data.user) throw new Error('REFRESH_FAILED');
  const {error: updateError} = await db.from('platform_sessions').update({
    refresh_token_hash: hashSecret(data.session.refresh_token),
    access_token_hash: hashSecret(data.session.access_token),
    rotation_counter: Number(stored.rotation_counter ?? 0) + 1,
    last_seen_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }).eq('id', platformSessionId).is('revoked_at', null);
  if (updateError) throw updateError;
  return {user: data.user, authSession: data.session, platformSession: stored};
}

export async function revokeSession(platformSessionId: string, reason = 'logout') {
  const db = adminDb();
  await db.from('platform_sessions').update({revoked_at: new Date().toISOString(), revoke_reason: reason, updated_at: new Date().toISOString()}).eq('id', platformSessionId).is('revoked_at', null);
}

export async function requestPasswordReset(email: string, redirectTo: string) {
  const client = authClient();
  await client.auth.resetPasswordForEmail(email, {redirectTo});
}

export async function updatePassword(accessToken: string, password: string) {
  const client = authClient();
  const {data, error: userError} = await client.auth.getUser(accessToken);
  if (userError || !data.user) throw new Error('INVALID_RECOVERY_TOKEN');
  const {error} = await adminDb().auth.admin.updateUserById(data.user.id, {password});
  if (error) throw new Error('PASSWORD_UPDATE_FAILED');
  await adminDb().from('platform_sessions').update({revoked_at: new Date().toISOString(), revoke_reason: 'password_changed', updated_at: new Date().toISOString()}).eq('user_id', data.user.id).is('revoked_at', null);
}

export async function resendVerification(email: string, redirectTo: string) {
  const client = authClient();
  const {error} = await client.auth.resend({type: 'signup', email, options: {emailRedirectTo: redirectTo}});
  if (error) throw new Error('VERIFICATION_SEND_FAILED');
}
