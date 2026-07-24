import {NextResponse} from 'next/server';
import {requireAuthenticated} from '@studio-os/auth';
import {writeAudit} from '@/lib/platform/audit';
import {getRequestContext} from '@/lib/platform/context';
import {apiError} from '@/lib/platform/http';
import {readSession} from '@/lib/platform/identity';

export async function POST(request: Request) {
  const context = getRequestContext(request);
  try {
    const session = requireAuthenticated(readSession(request));
    writeAudit(context, {action: 'identity.session.revoked', resourceType: 'session', resourceId: session.sessionId, metadata: {reason: 'logout'}});
    return NextResponse.json({data: {revoked: true}, requestId: context.requestId}, {headers: {'x-request-id': context.requestId}});
  } catch (error) {
    return apiError(error, context.requestId);
  }
}
