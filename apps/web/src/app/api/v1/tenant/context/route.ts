import {NextResponse} from 'next/server';
import {apiError} from '@/lib/platform/http';
import {withTenantContext} from '@/lib/tenancy/context';

export async function GET(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  try {
    return await withTenantContext(request, async context => NextResponse.json({data: context, requestId: context.requestId}, {headers: {'x-request-id': context.requestId, 'x-organisation-id': context.organisationId}}));
  } catch (error) {
    return apiError(error, requestId);
  }
}
