import {adminDb} from '@/lib/spread-manager-server';
import {selectOrganisation} from '@/lib/platform/identity';

export async function switchActiveOrganisation(userId: string, sessionId: string, organisationId: string) {
  const organisation = await selectOrganisation(userId, organisationId);
  const {error} = await adminDb().rpc('switch_active_organisation', {
    p_session_id: sessionId,
    p_organisation_id: organisation.id,
  });
  if (error) throw error;
  return organisation;
}
