import { ApiError, adminDb, type Actor } from '@/lib/spread-manager-server';
import type { SpreadManagerData } from './types';

const first = <T,>(value: T | T[] | null): T | null => Array.isArray(value) ? value[0] ?? null : value;

function workflowError(error: { message: string; code?: string }, fallbackCode: string): ApiError {
  const known: Record<string, [number, string]> = {
    SPREAD_LOCKED: [409, 'SPREAD_LOCKED'],
    BLOCKING_REVIEW_COMMENTS: [409, 'BLOCKING_REVIEW_COMMENTS'],
    REVIEW_REQUIRED: [409, 'REVIEW_REQUIRED'],
    ACTIVE_APPROVAL_EXISTS: [409, 'ACTIVE_APPROVAL_EXISTS'],
    REVIEW_ALREADY_COMPLETED: [409, 'REVIEW_ALREADY_COMPLETED'],
    APPROVAL_ALREADY_REVOKED: [409, 'APPROVAL_ALREADY_REVOKED'],
    APPROVED_DECISION_IMMUTABLE: [409, 'APPROVED_DECISION_IMMUTABLE'],
    TASK_DEPENDENCY_CYCLE: [409, 'TASK_DEPENDENCY_CYCLE'],
    TASK_DEPENDENCY_SELF_REFERENCE: [409, 'TASK_DEPENDENCY_SELF_REFERENCE'],
    TASK_DEPENDENCY_SPREAD_MISMATCH: [422, 'TASK_DEPENDENCY_SPREAD_MISMATCH'],
    TASK_DEPENDENCY_NOT_FOUND: [404, 'TASK_DEPENDENCY_NOT_FOUND'],
    SPREAD_ALREADY_LOCKED: [409, 'SPREAD_ALREADY_LOCKED'],
    SPREAD_NOT_LOCKED: [409, 'SPREAD_NOT_LOCKED'],
    DECISION_ALREADY_APPROVED: [409, 'DECISION_ALREADY_APPROVED'],
    DECISION_NOT_APPROVED: [409, 'DECISION_NOT_APPROVED'],
    DECISION_ALREADY_SUPERSEDED: [409, 'DECISION_ALREADY_SUPERSEDED'],
    DECISION_SUPERSEDED: [409, 'DECISION_SUPERSEDED'],
    COMMENT_ALREADY_RESOLVED: [409, 'COMMENT_ALREADY_RESOLVED'],
    DUPLICATE_REVIEW_REQUEST: [409, 'DUPLICATE_REVIEW_REQUEST'],
    REVIEWER_INACTIVE: [422, 'REVIEWER_INACTIVE'],
    CHARACTER_ALREADY_LINKED: [409, 'CHARACTER_ALREADY_LINKED'],
    DUPLICATE_CODE: [409, 'DUPLICATE_CODE'],
  };
  const key = Object.keys(known).find(value => error.message.includes(value));
  const [status, code] = key ? known[key] : [500, fallbackCode];
  return new ApiError(status, code, error.message);
}

export async function getManager(spreadId: string, actor: Actor): Promise<SpreadManagerData> {
  const db = adminDb();
  const { data: spread } = await db.from('vw_spread_board').select('*').eq('spread_id', spreadId).single();
  if (!spread) throw new ApiError(404, 'RESOURCE_NOT_FOUND', 'Spread not found.');

  const [assetResult, appearanceResult, libraryResult, taskResult, decisionResult, userResult] = await Promise.all([
    db.from('assets').select(`
      id,asset_code,asset_type,title,description,status,current_version_id,
      asset_versions(id,version_number,original_filename,file_size_bytes,change_summary,is_current,is_approved,uploaded_at),
      review_requests(id,asset_version_id,review_type,status,due_date,assigned_reviewer,users!review_requests_assigned_reviewer_fkey(id,display_name),
        reviews(id,summary,decision_recommendation,review_comments(id,comment,severity,is_resolved,resolution_note))),
      approvals(id,asset_version_id,approval_type,decision,decision_reason,created_at,revoked_at,revocation_reason)
    `).eq('spread_id', spreadId).is('archived_at', null).order('created_at'),
    db.from('character_appearances').select(`
      id,character_id,appearance_type,role_in_scene,continuity_notes,
      characters(id,character_code,name,status,current_version_id,character_versions!characters_current_version_id_fkey(version_number))
    `).eq('spread_id', spreadId),
    db.from('characters').select('id,character_code,name,status').is('archived_at', null).order('name'),
    db.from('vw_tasks').select('*').eq('spread_id', spreadId).order('due_date', { ascending: true, nullsFirst: false }),
    db.from('vw_decisions').select('*').eq('spread_id', spreadId).order('decision_date', { ascending: false, nullsFirst: false }),
    db.from('users').select('id,display_name,email').eq('is_active', true).order('display_name'),
  ]);

  if (assetResult.error) throw new ApiError(500, 'LOAD_FAILED', assetResult.error.message);
  if (appearanceResult.error) throw new ApiError(500, 'CHARACTER_LOAD_FAILED', appearanceResult.error.message);
  if (taskResult.error) throw new ApiError(500, 'TASK_LOAD_FAILED', taskResult.error.message);
  if (decisionResult.error) throw new ApiError(500, 'DECISION_LOAD_FAILED', decisionResult.error.message);

  return {
    spread: {
      id: spread.spread_id, publicationId: spread.publication_id,
      publicationCode: spread.publication_code, publicationTitle: spread.publication_title,
      spreadNumber: spread.spread_number, spreadKey: spread.spread_key,
      workingTitle: spread.working_title, storyPurpose: spread.story_purpose,
      emotionalGoal: spread.emotional_goal, illustrationBrief: spread.illustration_brief ?? null,
      designNotes: spread.design_notes ?? null, status: spread.status,
      editorialStatus: spread.editorial_status, artStatus: spread.art_status,
      designStatus: spread.design_status, lockedAt: spread.locked_at,
    },
    assets: (assetResult.data ?? []).map((a) => ({
      id: a.id, assetCode: a.asset_code, assetType: a.asset_type, title: a.title,
      description: a.description, status: a.status, currentVersionId: a.current_version_id,
      versions: (a.asset_versions ?? []).sort((x, y) => y.version_number - x.version_number).map((v) => ({
        id: v.id, versionNumber: v.version_number, originalFilename: v.original_filename,
        fileSizeBytes: v.file_size_bytes, changeSummary: v.change_summary,
        isCurrent: v.is_current, isApproved: v.is_approved, uploadedAt: v.uploaded_at,
      })),
      reviews: (a.review_requests ?? []).map((r) => {
        const reviewer = first(r.users); const result = first(r.reviews);
        return { id: r.id, assetVersionId: r.asset_version_id, reviewType: r.review_type, status: r.status, dueDate: r.due_date,
          reviewer: reviewer ? { id: reviewer.id, displayName: reviewer.display_name } : null,
          summary: result?.summary ?? null, recommendation: result?.decision_recommendation ?? null,
          comments: (result?.review_comments ?? []).map((c) => ({ id: c.id, comment: c.comment, severity: c.severity, isResolved: c.is_resolved, resolutionNote: c.resolution_note })) };
      }),
      approvals: (a.approvals ?? []).map((ap) => ({ id: ap.id, assetVersionId: ap.asset_version_id, approvalType: ap.approval_type,
        decision: ap.decision, decisionReason: ap.decision_reason, approvedAt: ap.created_at,
        revokedAt: ap.revoked_at, revocationReason: ap.revocation_reason })),
    })),
    characters: (appearanceResult.data ?? []).map((row) => {
      const c = first(row.characters); const version = c ? first(c.character_versions) : null;
      return { appearanceId: row.id, characterId: row.character_id, characterCode: c?.character_code ?? '',
        name: c?.name ?? 'Unknown character', status: c?.status ?? 'Unknown', appearanceType: row.appearance_type,
        roleInScene: row.role_in_scene, continuityNotes: row.continuity_notes,
        currentVersionId: c?.current_version_id ?? null, currentVersionNumber: version?.version_number ?? null };
    }),
    characterLibrary: (libraryResult.data ?? []).map((c) => ({ id: c.id, characterCode: c.character_code, name: c.name, status: c.status })),
    tasks: (taskResult.data ?? []).map((t) => ({ id: t.task_id, title: t.title, description: t.description,
      department: t.department, status: t.status, priority: t.priority, assignedTo: t.assigned_to,
      ownerName: t.owner_name, startDate: t.start_date, dueDate: t.due_date, blocked: t.blocked,
      blockedReason: t.blocked_reason, dependencyCount: t.dependency_count,
      incompleteDependencyCount: t.incomplete_dependency_count, daysRemaining: t.days_remaining, overdue: t.overdue })),
    decisions: (decisionResult.data ?? []).map((d) => ({ id: d.decision_id, decisionCode: d.decision_code,
      title: d.title, context: d.context, optionsConsidered: d.options_considered, finalDecision: d.final_decision,
      reason: d.reason, decisionOwner: d.decision_owner, decisionOwnerName: d.decision_owner_name,
      decisionDate: d.decision_date, status: d.status, isSuperseded: d.is_superseded,
      supersedesDecisionId: d.supersedes_decision_id })),
    users: (userResult.data ?? []).map((u) => ({ id: u.id, displayName: u.display_name, email: u.email })),
    permissions: [...actor.permissions],
  };
}

export async function addCharacter(actor: Actor, spreadId: string, input: { characterId: string; appearanceType?: string; roleInScene?: string; continuityNotes?: string }) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_add_character_appearance', {
    p_spread_id: spreadId, p_character_id: input.characterId, p_actor_id: actor.profileId,
    p_appearance_type: input.appearanceType ?? null, p_role_in_scene: input.roleInScene ?? null,
    p_continuity_notes: input.continuityNotes ?? null,
  }).single();
  if (error) throw workflowError(error, 'CHARACTER_LINK_FAILED');
  return data;
}

export async function removeCharacter(actor: Actor, spreadId: string, appearanceId: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_remove_character_appearance', {
    p_spread_id: spreadId, p_appearance_id: appearanceId, p_actor_id: actor.profileId,
  }).single();
  if (error) throw workflowError(error, 'CHARACTER_REMOVE_FAILED');
  return data;
}

export async function createTask(actor: Actor, spreadId: string, input: { title: string; description?: string; department?: string; priority: string; assignedTo?: string; dueDate?: string }) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_create_task', {
    p_spread_id: spreadId, p_actor_id: actor.profileId, p_title: input.title,
    p_description: input.description ?? null, p_department: input.department ?? null,
    p_priority: input.priority, p_assigned_to: input.assignedTo ?? null, p_due_date: input.dueDate ?? null,
  }).single();
  if (error) throw workflowError(error, 'TASK_CREATE_FAILED');
  return data;
}

export async function updateTask(actor: Actor, spreadId: string, taskId: string, input: { status?: string; priority?: string; assignedTo?: string | null; dueDate?: string | null; blockedReason?: string | null }) {
  const db = adminDb();
  const patch: Record<string, unknown> = {};
  if (input.status !== undefined) patch.status = input.status;
  if (input.priority !== undefined) patch.priority = input.priority;
  if (input.assignedTo !== undefined) patch.assignedTo = input.assignedTo;
  if (input.dueDate !== undefined) patch.dueDate = input.dueDate;
  if (input.blockedReason !== undefined) patch.blockedReason = input.blockedReason;
  const { data, error } = await db.rpc('workflow_update_task', {
    p_spread_id: spreadId, p_task_id: taskId, p_actor_id: actor.profileId, p_patch: patch,
  }).single();
  if (error) throw workflowError(error, 'TASK_UPDATE_FAILED');
  return data;
}

export async function createDecision(actor: Actor, spreadId: string, input: { decisionCode: string; title: string; context?: string; optionsConsidered?: unknown; finalDecision: string; reason: string; status?: string }) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_create_decision', {
    p_spread_id: spreadId, p_actor_id: actor.profileId, p_decision_code: input.decisionCode,
    p_title: input.title, p_context: input.context ?? null, p_options_considered: input.optionsConsidered ?? [],
    p_final_decision: input.finalDecision, p_reason: input.reason, p_status: input.status ?? 'Proposed',
  }).single();
  if (error) throw workflowError(error, 'DECISION_CREATE_FAILED');
  return data;
}

export async function approveDecision(actor: Actor, spreadId: string, decisionId: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_approve_decision', {
    p_spread_id: spreadId, p_decision_id: decisionId, p_actor_id: actor.profileId,
  }).single();
  if (error) throw workflowError(error, 'DECISION_APPROVE_FAILED');
  return data;
}

export async function createReviewRequest(actor: Actor, spreadId: string, input: {
  assetId: string; assetVersionId: string; assignedReviewer: string; reviewType: string;
  instructions?: string | null; dueDate?: string | null;
}) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_create_review_request', {
    p_spread_id: spreadId, p_asset_id: input.assetId, p_asset_version_id: input.assetVersionId,
    p_actor_id: actor.profileId, p_assigned_reviewer: input.assignedReviewer,
    p_review_type: input.reviewType, p_instructions: input.instructions ?? null, p_due_date: input.dueDate ?? null,
  }).single();
  if (error) throw workflowError(error, 'REVIEW_CREATE_FAILED');
  return data;
}

export async function completeReview(actor: Actor, spreadId: string, reviewRequestId: string, input: {
  summary?: string | null; decisionRecommendation: string;
  comments: Array<{ comment: string; severity: string; pageNumber?: number | null; xPosition?: number | null; yPosition?: number | null }>;
}) {
  const db = adminDb();
  const { data: request } = await db.from('review_requests').select('id,spread_id,assigned_reviewer').eq('id', reviewRequestId).single();
  if (!request || request.spread_id !== spreadId) throw new ApiError(404, 'RESOURCE_NOT_FOUND', 'Review request not found.');
  if (request.assigned_reviewer !== actor.profileId && !actor.permissions.has('review.complete_any'))
    throw new ApiError(403, 'PERMISSION_DENIED', 'Only the assigned reviewer may complete this review.');
  const { data, error } = await db.rpc('workflow_complete_review', {
    p_review_request_id: reviewRequestId,
    p_actor_id: actor.profileId,
    p_summary: input.summary ?? null,
    p_decision_recommendation: input.decisionRecommendation,
    p_comments: input.comments,
  }).single();
  if (error) throw workflowError(error, 'REVIEW_COMPLETE_FAILED');
  return data;
}

export async function resolveReviewComment(actor: Actor, spreadId: string, commentId: string, resolutionNote: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_resolve_review_comment', {
    p_spread_id: spreadId, p_comment_id: commentId, p_actor_id: actor.profileId,
    p_resolution_note: resolutionNote,
  }).single();
  if (error) throw workflowError(error, 'COMMENT_RESOLVE_FAILED');
  return data;
}

export async function approveAssetVersion(actor: Actor, spreadId: string, assetId: string, versionId: string, input: { approvalType: string; decisionReason: string }) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_approve_asset_version', {
    p_spread_id: spreadId,
    p_asset_id: assetId,
    p_version_id: versionId,
    p_actor_id: actor.profileId,
    p_approval_type: input.approvalType,
    p_decision_reason: input.decisionReason,
  }).single();
  if (error) throw workflowError(error, 'APPROVAL_CREATE_FAILED');
  return data;
}

export async function revokeApproval(actor: Actor, spreadId: string, approvalId: string, revocationReason: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_revoke_approval', {
    p_spread_id: spreadId,
    p_approval_id: approvalId,
    p_actor_id: actor.profileId,
    p_revocation_reason: revocationReason,
  }).single();
  if (error) throw workflowError(error, 'APPROVAL_REVOKE_FAILED');
  return data;
}

export async function setSpreadLock(actor: Actor, spreadId: string, lock: boolean, reason: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_set_spread_lock', {
    p_spread_id: spreadId, p_actor_id: actor.profileId, p_lock: lock, p_reason: reason,
  }).single();
  if (error) throw workflowError(error, lock ? 'SPREAD_LOCK_FAILED' : 'SPREAD_UNLOCK_FAILED');
  return data;
}

export async function supersedeDecision(actor: Actor, spreadId: string, decisionId: string, input: {
  decisionCode: string; title: string; context?: string | null; optionsConsidered?: string[];
  finalDecision: string; reason: string;
}) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_supersede_decision', {
    p_spread_id: spreadId, p_decision_id: decisionId, p_actor_id: actor.profileId,
    p_decision_code: input.decisionCode, p_title: input.title, p_context: input.context ?? null,
    p_options_considered: input.optionsConsidered ?? [], p_final_decision: input.finalDecision, p_reason: input.reason,
  }).single();
  if (error) throw workflowError(error, 'DECISION_SUPERSEDE_FAILED');
  return data;
}

export async function uploadAssetVersion(actor: Actor, assetId: string, input: {
  originalFilename: string; storagePath: string; fileSizeBytes?: number | null; mimeType?: string | null;
  checksum?: string | null; changeSummary?: string | null; makeCurrent?: boolean;
}) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_upload_asset_version', {
    p_asset_id: assetId, p_actor_id: actor.profileId, p_original_filename: input.originalFilename,
    p_storage_path: input.storagePath, p_file_size_bytes: input.fileSizeBytes ?? null,
    p_mime_type: input.mimeType ?? null, p_checksum: input.checksum ?? null,
    p_change_summary: input.changeSummary ?? null, p_make_current: input.makeCurrent ?? true,
  }).single();
  if (error) throw workflowError(error, 'VERSION_UPLOAD_FAILED');
  return data;
}

export async function switchAssetVersion(actor: Actor, assetId: string, versionId: string, reason: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_switch_asset_version', {
    p_asset_id: assetId, p_version_id: versionId, p_actor_id: actor.profileId, p_reason: reason,
  }).single();
  if (error) throw workflowError(error, 'VERSION_SWITCH_FAILED');
  return data;
}

export async function addTaskDependency(actor: Actor, taskId: string, dependsOnTaskId: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_add_task_dependency', {
    p_task_id: taskId, p_depends_on_task_id: dependsOnTaskId, p_actor_id: actor.profileId,
  }).single();
  if (error) throw workflowError(error, 'TASK_DEPENDENCY_FAILED');
  return data;
}

export async function removeTaskDependency(actor: Actor, taskId: string, dependsOnTaskId: string) {
  const db = adminDb();
  const { data, error } = await db.rpc('workflow_remove_task_dependency', {
    p_task_id: taskId, p_depends_on_task_id: dependsOnTaskId, p_actor_id: actor.profileId,
  }).single();
  if (error) throw workflowError(error, 'TASK_DEPENDENCY_REMOVE_FAILED');
  return data;
}
