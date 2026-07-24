import {NextResponse} from 'next/server';
import {requireAuthenticated} from '@studio-os/auth';
import {getRequestContext} from '@/lib/platform/context';
import {apiError} from '@/lib/platform/http';
import {readSession} from '@/lib/platform/identity';

export async function GET(request: Request) {
  const context = getRequestContext(request);
  try {
    const session = requireAuthenticated(await readSession(request));
    return NextResponse.json({data: session, requestId: context.requestId}, {headers: {'x-request-id': context.requestId}});
  } catch (error) {
    return apiError(error, context.requestId);
  }
}
