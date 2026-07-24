import type {SessionIdentity} from '@studio-os/auth';
import {resolveTenant} from '@studio-os/tenancy';

export type OrganisationSummary = {
  id: string;
  slug: string;
  name: string;
  locale: string;
  timezone: string;
  isDefault: boolean;
};

const demoOrganisations: OrganisationSummary[] = [
  {id: '11111111-1111-4111-8111-111111111111', slug: 'studio-publishing', name: 'Studio Publishing', locale: 'en-ZA', timezone: 'Africa/Johannesburg', isDefault: true},
  {id: '22222222-2222-4222-8222-222222222222', slug: 'pilot-publisher', name: 'Pilot Publisher', locale: 'en-ZA', timezone: 'Africa/Johannesburg', isDefault: false},
];

export function readSession(request: Request): SessionIdentity | null {
  const userId = request.headers.get('x-user-id');
  if (!userId) return null;
  const organisationId = request.headers.get('x-organisation-id') ?? demoOrganisations[0].id;
  return {
    userId,
    email: request.headers.get('x-user-email') ?? 'admin@studioos.local',
    organisationId,
    sessionId: request.headers.get('x-session-id') ?? 'development-session',
    expiresAt: request.headers.get('x-session-expires-at') ?? new Date(Date.now() + 60 * 60 * 1000).toISOString(),
  };
}

export function listOrganisations(_userId: string): OrganisationSummary[] {
  return demoOrganisations;
}

export function selectOrganisation(request: Request, requestedId: string): OrganisationSummary {
  const memberships = demoOrganisations.map(item => item.id);
  const selectedId = resolveTenant({header: requestedId, membershipIds: memberships, defaultId: demoOrganisations.find(item => item.isDefault)?.id});
  const selected = demoOrganisations.find(item => item.id === selectedId);
  if (!selected) throw new Error('TENANT_NOT_FOUND');
  return selected;
}
