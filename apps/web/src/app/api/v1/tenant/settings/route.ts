import {NextResponse} from 'next/server';
import {adminDb} from '@/lib/spread-manager-server';
import {apiError} from '@/lib/platform/http';
import {getTenantContext} from '@/lib/tenancy/context';

export async function GET(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  try {
    const context = await getTenantContext(request);
    const {data, error} = await adminDb().rpc('get_tenant_settings', {
      p_organisation_id: context.organisationId,
      p_user_id: context.userId,
      p_request_id: context.requestId,
    });
    if (error) throw error;
    return NextResponse.json({data: data?.[0] ?? null, requestId: context.requestId}, {headers: {'x-request-id': context.requestId}});
  } catch (error) {
    return apiError(error, requestId);
  }
}
