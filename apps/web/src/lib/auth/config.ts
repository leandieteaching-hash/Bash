export const ACCESS_COOKIE = 'studio_access_token';
export const REFRESH_COOKIE = 'studio_refresh_token';
export const SESSION_COOKIE = 'studio_session_id';
export const ACTIVE_ORGANISATION_COOKIE = 'studio_organisation_id';

export const authDurations = {
  accessSeconds: 60 * 60,
  sessionSeconds: 60 * 60 * 8,
  rememberedSessionSeconds: 60 * 60 * 24 * 30,
  resetSeconds: 60 * 30,
  verificationSeconds: 60 * 60 * 24,
} as const;

export function secureCookie(maxAge: number) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax' as const,
    path: '/',
    maxAge,
  };
}
