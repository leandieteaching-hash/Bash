import {NextResponse} from 'next/server';
import {readCookie, setAuthCookies, clearAuthCookies} from '@/lib/auth/cookies';
import {REFRESH_COOKIE, SESSION_COOKIE} from '@/lib/auth/config';
import {rotateRefreshToken, revokeSession} from '@/lib/auth/service';
import {recordAuthAudit} from '@/lib/auth/audit';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const refreshToken = readCookie(request, REFRESH_COOKIE);
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (!refreshToken || !sessionId) return NextResponse.json({error: {code: 'UNAUTHENTICATED'}, requestId}, {status: 401});
  try {
    const result = await rotateRefreshToken(refreshToken, sessionId);
    const response = NextResponse.json({data: {refreshed: true}, requestId});
    setAuthCookies(response, {accessToken: result.authSession.access_token, refreshToken: result.authSession.refresh_token, sessionId, organisationId: result.platformSession.organisation_id, rememberMe: Boolean(result.platformSession.remember_me)});
    return response;
  } catch {
    await revokeSession(sessionId, 'refresh_failed').catch(() => undefined);
    const response = NextResponse.json({error: {code: 'SESSION_EXPIRED'}, requestId}, {status: 401});
    clearAuthCookies(response);
    await recordAuthAudit({requestId, organisationId: null, action: 'identity.session.refresh_failed', resourceType: 'session', resourceId: sessionId});
    return response;
  }
}
