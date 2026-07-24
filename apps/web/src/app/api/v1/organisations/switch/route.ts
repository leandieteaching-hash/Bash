import {NextResponse} from 'next/server';
import {ACTIVE_ORGANISATION_COOKIE} from '@/lib/auth/config';
import {secureCookie} from '@/lib/auth/config';
import {recordAuthAudit} from '@/lib/auth/audit';
import {apiError} from '@/lib/platform/http';
import {readSession} from '@/lib/platform/identity';
import {switchActiveOrganisation} from '@/lib/tenancy/switch';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  try {
    const session = await readSession(request);
    if (!session) throw new Error('UNAUTHENTICATED');
    const body = (await request.json()) as {organisationId?: string};
    if (!body.organisationId) throw new Error('VALIDATION_ERROR');
    const organisation = await switchActiveOrganisation(session.userId, session.sessionId, body.organisationId);
    await recordAuthAudit({requestId, organisationId: organisation.id, actorId: session.userId, action: 'tenant.switched', resourceType: 'organisation', resourceId: organisation.id, metadata: {previousOrganisationId: session.organisationId}});
    const response = NextResponse.json({data: organisation, requestId}, {headers: {'x-request-id': requestId, 'x-organisation-id': organisation.id}});
    response.cookies.set(ACTIVE_ORGANISATION_COOKIE, organisation.id, secureCookie(60 * 60 * 24 * 30));
    return response;
  } catch (error) {
    return apiError(error, requestId);
  }
}
