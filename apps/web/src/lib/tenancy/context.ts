import type {TenantContext, TenantMembership} from '@studio-os/tenancy';
import {resolveTenant} from '@studio-os/tenancy';
import {readSession, listOrganisations} from '@/lib/platform/identity';

export async function getTenantContext(request: Request): Promise<TenantContext> {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const session = await readSession(request);
  if (!session) throw new Error('UNAUTHENTICATED');
  const memberships = (await listOrganisations(session.userId)) as TenantMembership[];
  const organisationId = resolveTenant({
    sessionId: session.organisationId,
    membershipIds: memberships.map(item => item.id),
    defaultId: memberships.find(item => item.isDefault)?.id,
  });
  const organisation = memberships.find(item => item.id === organisationId);
  if (!organisation) throw new Error('TENANT_NOT_FOUND');
  return {...organisation, organisationId: organisation.id, userId: session.userId, sessionId: session.sessionId, requestId};
}

export async function withTenantContext<T>(request: Request, operation: (context: TenantContext) => Promise<T>): Promise<T> {
  return operation(await getTenantContext(request));
}
