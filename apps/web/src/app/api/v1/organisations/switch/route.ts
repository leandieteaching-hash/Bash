import {NextResponse} from 'next/server';
import {requireAuthenticated} from '@studio-os/auth';
import {writeAudit} from '@/lib/platform/audit';
import {getRequestContext} from '@/lib/platform/context';
import {apiError} from '@/lib/platform/http';
import {readSession, selectOrganisation} from '@/lib/platform/identity';

export async function POST(request: Request) {
  const context = getRequestContext(request);
  try {
    const session = requireAuthenticated(readSession(request));
    const body = (await request.json()) as {organisationId?: string};
    if (!body.organisationId) return NextResponse.json({error: {code: 'VALIDATION_ERROR', message: 'organisationId is required'}, requestId: context.requestId}, {status: 400});
    const organisation = selectOrganisation(request, body.organisationId);
    writeAudit({...context, tenantId: organisation.id, userId: session.userId}, {action: 'tenant.switched', resourceType: 'organisation', resourceId: organisation.id, metadata: {previousOrganisationId: session.organisationId}});
    return NextResponse.json({data: organisation, requestId: context.requestId}, {headers: {'x-request-id': context.requestId, 'x-organisation-id': organisation.id}});
  } catch (error) {
    return apiError(error, context.requestId);
  }
}
