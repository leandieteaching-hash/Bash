import {NextResponse} from 'next/server';
import {loginWithPassword} from '@/lib/auth/service';
import {loginSchema} from '@/lib/auth/validation';
import {setAuthCookies} from '@/lib/auth/cookies';
import {clientAddress, consumeRateLimit} from '@/lib/auth/rate-limit';
import {hashSecret} from '@/lib/auth/crypto';
import {adminDb} from '@/lib/spread-manager-server';
import {recordAuthAudit} from '@/lib/auth/audit';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const parsed = loginSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({error: {code: 'INVALID_REQUEST', details: parsed.error.flatten()}, requestId}, {status: 400});
  const ip = clientAddress(request);
  const rate = consumeRateLimit(`login:${ip}:${parsed.data.email.toLowerCase()}`);
  if (!rate.allowed) return NextResponse.json({error: {code: 'RATE_LIMITED'}, requestId}, {status: 429, headers: {'retry-after': String(rate.retryAfterSeconds)}});
  try {
    const result = await loginWithPassword({...parsed.data, request});
    await adminDb().from('platform_login_attempts').insert({email_hash: hashSecret(parsed.data.email.toLowerCase()), ip_address: ip === 'unknown' ? null : ip, succeeded: true});
    await recordAuthAudit({requestId, organisationId: result.organisationId, actorId: result.user.id, action: 'identity.login.succeeded', resourceType: 'session', resourceId: result.platformSessionId});
    const response = NextResponse.json({data: {user: {id: result.user.id, email: result.user.email}, organisationId: result.organisationId, expiresAt: result.expiresAt}, requestId});
    setAuthCookies(response, {accessToken: result.authSession.access_token, refreshToken: result.authSession.refresh_token, sessionId: result.platformSessionId, organisationId: result.organisationId, rememberMe: parsed.data.rememberMe});
    response.headers.set('x-request-id', requestId);
    return response;
  } catch (error) {
    try { await adminDb().from('platform_login_attempts').insert({email_hash: hashSecret(parsed.data.email.toLowerCase()), ip_address: ip === 'unknown' ? null : ip, succeeded: false, failure_code: error instanceof Error ? error.message : 'UNKNOWN'}); } catch { /* preserve non-enumerating response */ }
    return NextResponse.json({error: {code: 'INVALID_CREDENTIALS', message: 'The email or password is incorrect.'}, requestId}, {status: 401, headers: {'x-request-id': requestId}});
  }
}
