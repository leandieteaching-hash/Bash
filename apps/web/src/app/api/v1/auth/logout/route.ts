import {NextResponse} from 'next/server';
import {clearAuthCookies, readCookie} from '@/lib/auth/cookies';
import {SESSION_COOKIE} from '@/lib/auth/config';
import {revokeSession} from '@/lib/auth/service';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const sessionId = readCookie(request, SESSION_COOKIE);
  if (sessionId) await revokeSession(sessionId).catch(() => undefined);
  const response = NextResponse.json({data: {revoked: true}, requestId});
  clearAuthCookies(response);
  return response;
}
