export type SessionIdentity = {
  userId: string;
  email: string;
  organisationId: string | null;
  sessionId: string;
  expiresAt: string;
};

export type SessionCookieOptions = {
  httpOnly: true;
  secure: boolean;
  sameSite: 'lax';
  path: '/';
  maxAge: number;
};

export function sessionCookieOptions(rememberMe: boolean, production = false): SessionCookieOptions {
  return {
    httpOnly: true,
    secure: production,
    sameSite: 'lax',
    path: '/',
    maxAge: rememberMe ? 60 * 60 * 24 * 30 : 60 * 60 * 8,
  };
}

export function requireAuthenticated(identity: SessionIdentity | null): SessionIdentity {
  if (!identity) throw new Error('UNAUTHENTICATED');
  if (Date.parse(identity.expiresAt) <= Date.now()) throw new Error('SESSION_EXPIRED');
  return identity;
}
