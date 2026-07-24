import {NextResponse} from 'next/server';

export function apiError(error: unknown, requestId: string) {
  const message = error instanceof Error ? error.message : 'INTERNAL_ERROR';
  const [code] = message.split(':');
  const status = code === 'UNAUTHENTICATED' || code === 'SESSION_EXPIRED' ? 401 : code.startsWith('TENANT_') || code === 'FORBIDDEN' ? 403 : 500;
  return NextResponse.json({error: {code, message: code === 'INTERNAL_ERROR' ? 'An unexpected error occurred.' : message}, requestId}, {status, headers: {'x-request-id': requestId}});
}
