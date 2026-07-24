import {adminDb} from '@/lib/spread-manager-server';

export async function recordAuthAudit(input: {
  requestId: string;
  organisationId?: string | null;
  actorId?: string | null;
  action: string;
  resourceType?: string;
  resourceId?: string | null;
  metadata?: Record<string, unknown>;
}) {
  if (!input.organisationId) return;
  const {error} = await adminDb().from('platform_audit_events').insert({
    organisation_id: input.organisationId,
    request_id: input.requestId,
    actor_id: input.actorId ?? null,
    action: input.action,
    resource_type: input.resourceType ?? 'identity',
    resource_id: input.resourceId ?? null,
    metadata: input.metadata ?? {},
  });
  if (error) console.error('Authentication audit write failed', error);
}
