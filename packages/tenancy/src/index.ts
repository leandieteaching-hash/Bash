export type TenantContext = {
  organisationId: string;
  slug: string;
  name: string;
  locale: string;
  timezone: string;
  userId: string;
  sessionId: string;
  requestId: string;
};

export type TenantMembership = Omit<TenantContext, 'userId' | 'sessionId' | 'requestId'> & {
  isDefault: boolean;
};

export function resolveTenant(input: {
  requestedId?: string | null;
  sessionId?: string | null;
  membershipIds: string[];
  defaultId?: string | null;
}): string {
  const candidate = input.requestedId ?? input.sessionId ?? input.defaultId ?? input.membershipIds[0];
  if (!candidate || !input.membershipIds.includes(candidate)) throw new Error('TENANT_ACCESS_DENIED');
  return candidate;
}

export function tenantDatabaseSettings(context: Pick<TenantContext, 'organisationId' | 'userId' | 'requestId'>) {
  return {
    'app.organisation_id': context.organisationId,
    'app.user_id': context.userId,
    'app.request_id': context.requestId,
  } as const;
}

export function assertTenantResource(context: Pick<TenantContext, 'organisationId'>, resourceOrganisationId: string) {
  if (context.organisationId !== resourceOrganisationId) throw new Error('TENANT_RESOURCE_MISMATCH');
}
