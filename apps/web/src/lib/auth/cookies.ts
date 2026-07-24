import {NextResponse} from 'next/server';
import {ACCESS_COOKIE, ACTIVE_ORGANISATION_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, authDurations, secureCookie} from './config';

export type AuthCookiePayload = {accessToken: string; refreshToken: string; sessionId: string; organisationId: string | null; rememberMe: boolean};

export function setAuthCookies(response: NextResponse, payload: AuthCookiePayload) {
  const maxAge = payload.rememberMe ? authDurations.rememberedSessionSeconds : authDurations.sessionSeconds;
  response.cookies.set(ACCESS_COOKIE, payload.accessToken, secureCookie(Math.min(maxAge, authDurations.accessSeconds)));
  response.cookies.set(REFRESH_COOKIE, payload.refreshToken, secureCookie(maxAge));
  response.cookies.set(SESSION_COOKIE, payload.sessionId, secureCookie(maxAge));
  if (payload.organisationId) response.cookies.set(ACTIVE_ORGANISATION_COOKIE, payload.organisationId, secureCookie(maxAge));
}

export function clearAuthCookies(response: NextResponse) {
  for (const name of [ACCESS_COOKIE, REFRESH_COOKIE, SESSION_COOKIE, ACTIVE_ORGANISATION_COOKIE]) {
    response.cookies.set(name, '', {...secureCookie(0), expires: new Date(0)});
  }
}

export function readCookie(request: Request, name: string): string | null {
  const cookie = request.headers.get('cookie') ?? '';
  for (const part of cookie.split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('='));
  }
  return null;
}
