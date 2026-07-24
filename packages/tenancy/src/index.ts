export type TenantContext = {
  organisationId: string;
  slug: string;
  name: string;
  locale: string;
  timezone: string;
};

export function resolveTenant(input: { header?: string | null; membershipIds: string[]; defaultId?: string | null }): string {
  const candidate = input.header ?? input.defaultId ?? input.membershipIds[0];
  if (!candidate || !input.membershipIds.includes(candidate)) throw new Error('TENANT_ACCESS_DENIED');
  return candidate;
}

export function tenantDatabaseSettings(context: Pick<TenantContext, 'organisationId'>, userId: string) {
  return { 'app.organisation_id': context.organisationId, 'app.user_id': userId } as const;
}
