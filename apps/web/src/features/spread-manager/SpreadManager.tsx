'use client';

import { FormEvent, ReactNode, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { Asset, AssetReview, SpreadDecision, SpreadManagerData, SpreadTask } from './types';
import styles from './spread-manager.module.css';
import { useSpreadRealtime, type CollaborationEvent, type CollaborationStatus } from './use-spread-realtime';

type MainTab = 'assets' | 'characters' | 'tasks' | 'decisions';
type AssetTab = 'versions' | 'reviews' | 'approvals';
type Notice = { kind: 'success' | 'error'; message: string } | null;
type FieldErrors = Record<string, string>;

async function call<T = unknown>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options?.headers ?? {}) },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.error?.message ?? 'Request failed.');
  return body.data as T;
}

export function SpreadManager({ spreadId }: { spreadId: string }) {
  const [data, setData] = useState<SpreadManagerData | null>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [main, setMain] = useState<MainTab>('assets');
  const [assetTab, setAssetTab] = useState<AssetTab>('versions');
  const [notice, setNotice] = useState<Notice>(null);
  const [lockModal, setLockModal] = useState(false);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);
  const requestSequence = useRef(0);

  const refresh = useCallback(async ({ silent = false }: { silent?: boolean } = {}) => {
    const sequence = ++requestSequence.current;
    if (silent) setSyncing(true);
    else setLoading(true);
    try {
      const next = await call<SpreadManagerData>(`/api/v1/spreads/${spreadId}/manager`, { cache: 'no-store' });
      if (sequence !== requestSequence.current) return;
      setData(next);
      setSelected(current => current && next.assets.some(a => a.id === current) ? current : next.assets[0]?.id ?? null);
      setLastSyncedAt(new Date().toISOString());
    } catch (error) {
      if (!silent) setNotice({ kind: 'error', message: error instanceof Error ? error.message : 'The Spread Manager could not load.' });
    } finally {
      if (sequence === requestSequence.current) {
        if (silent) setSyncing(false);
        else setLoading(false);
      }
    }
  }, [spreadId]);

  const reconcileRealtimeChange = useCallback(async (_event: CollaborationEvent) => {
    await refresh({ silent: true });
  }, [refresh]);

  const collaboration = useSpreadRealtime({
    spreadId,
    enabled: Boolean(data),
    onChange: reconcileRealtimeChange,
  });

  useEffect(() => { void refresh(); }, [refresh]);
  useEffect(() => {
    if (!notice || notice.kind !== 'success') return;
    const timer = window.setTimeout(() => setNotice(null), 4500);
    return () => window.clearTimeout(timer);
  }, [notice]);

  const asset = useMemo(() => data?.assets.find(item => item.id === selected) ?? null, [data, selected]);

  async function runAction(action: () => Promise<unknown>, successMessage: string) {
    setNotice(null);
    try {
      await action();
      await refresh({ silent: true });
      setNotice({ kind: 'success', message: successMessage });
      return true;
    } catch (error) {
      setNotice({ kind: 'error', message: error instanceof Error ? error.message : 'The action could not be completed.' });
      return false;
    }
  }

  if (loading && !data) return <div className={styles.state}>Loading Spread Manager…</div>;
  if (!data) return <div className={styles.state}>{notice?.message ?? 'Spread Manager data is unavailable.'}</div>;

  return (
    <main className={styles.page} aria-busy={loading}>
      <header className={styles.header}>
        <div>
          <small>{data.spread.publicationCode} · Spread {data.spread.spreadNumber}</small>
          <h1>{data.spread.workingTitle ?? data.spread.spreadKey}</h1>
          <p>{data.spread.storyPurpose}</p>
          {data.spread.lockedAt && <span className={styles.lockBadge}>Locked</span>}
        </div>
        <div className={styles.headerTools}>
          <CollaborationIndicator status={collaboration.status} syncing={syncing} lastSyncedAt={lastSyncedAt}
            lastTable={collaboration.lastEvent?.table ?? null} />
          <div className={styles.actions}>
            {data.permissions.includes('spread.lock') && (
              <button type="button" onClick={() => setLockModal(true)}>
                {data.spread.lockedAt ? 'Unlock spread' : 'Lock spread'}
              </button>
            )}
          </div>
        </div>
      </header>

      {notice && <NoticeBanner notice={notice} onDismiss={() => setNotice(null)} />}

      <nav className={styles.mainTabs} aria-label="Spread manager sections">
        {(['assets', 'characters', 'tasks', 'decisions'] as MainTab[]).map(tab => (
          <button key={tab} className={main === tab ? styles.active : ''} onClick={() => setMain(tab)}>
            {capitalize(tab)}
          </button>
        ))}
      </nav>

      {main === 'assets' && (
        <Assets data={data} asset={asset} selected={selected} setSelected={setSelected} tab={assetTab}
          setTab={setAssetTab} spreadId={spreadId} runAction={runAction} />
      )}
      {main === 'characters' && <Characters data={data} />}
      {main === 'tasks' && <Tasks data={data} spreadId={spreadId} runAction={runAction} />}
      {main === 'decisions' && <Decisions data={data} spreadId={spreadId} runAction={runAction} />}

      <LockSpreadModal open={lockModal} locked={Boolean(data.spread.lockedAt)} onClose={() => setLockModal(false)}
        onSubmit={async reason => {
          const action = data.spread.lockedAt ? 'unlock' : 'lock';
          const ok = await runAction(
            () => call(`/api/v1/spreads/${spreadId}/${action}`, { method: 'POST', body: JSON.stringify({ reason }) }),
            data.spread.lockedAt ? 'Spread unlocked successfully.' : 'Spread locked successfully.',
          );
          if (ok) setLockModal(false);
          return ok;
        }} />
    </main>
  );
}

function CollaborationIndicator({ status, syncing, lastSyncedAt, lastTable }: {
  status: CollaborationStatus; syncing: boolean; lastSyncedAt: string | null; lastTable: string | null;
}) {
  const label = syncing ? 'Syncing changes…' : {
    connecting: 'Connecting…', live: 'Live collaboration', reconnecting: 'Reconnecting…',
    offline: 'Offline', error: 'Realtime unavailable',
  }[status];
  const title = lastSyncedAt
    ? `Last synchronized ${new Date(lastSyncedAt).toLocaleTimeString()}${lastTable ? ` after ${lastTable.replaceAll('_', ' ')} changed` : ''}`
    : 'Waiting for the first synchronization';
  return <div className={`${styles.collaboration} ${styles[`collaboration_${status}`]}`} role="status" title={title}>
    <span className={styles.liveDot} aria-hidden="true" />
    <span>{label}</span>
  </div>;
}

function Assets({ data, asset, selected, setSelected, tab, setTab, spreadId, runAction }: {
  data: SpreadManagerData; asset: Asset | null; selected: string | null; setSelected: (id: string) => void;
  tab: AssetTab; setTab: (tab: AssetTab) => void; spreadId: string;
  runAction: (action: () => Promise<unknown>, success: string) => Promise<boolean>;
}) {
  const [reviewAsset, setReviewAsset] = useState<Asset | null>(null);
  const [approval, setApproval] = useState<{ asset: Asset; versionId: string; versionNumber: number } | null>(null);
  const [revocation, setRevocation] = useState<{ id: string; label: string } | null>(null);
  const [uploadAsset, setUploadAsset] = useState<Asset | null>(null);
  const [switchVersion, setSwitchVersion] = useState<{ asset: Asset; versionId: string; versionNumber: number } | null>(null);

  return (
    <section className={styles.workspace}>
      <aside>
        <h2>Assets</h2>
        {data.assets.map(item => (
          <button key={item.id} className={selected === item.id ? styles.selected : ''} onClick={() => setSelected(item.id)}>
            <strong>{item.title}</strong><span>{item.assetType}</span><small>{item.status}</small>
          </button>
        ))}
      </aside>
      <div className={styles.detail}>
        {!asset ? <p className={styles.empty}>No assets are linked to this spread.</p> : <>
          <div className={styles.toolbar}>
            <div><h2>{asset.title}</h2><small>{asset.assetCode} · {asset.status}</small></div>
            <div className={styles.actions}>
              {data.permissions.includes('asset.upload') &&
                <button onClick={() => setUploadAsset(asset)}>Upload version</button>}
              {data.permissions.includes('review.request') && asset.versions.length > 0 &&
                <button onClick={() => setReviewAsset(asset)}>Request review</button>}
            </div>
          </div>
          <nav aria-label="Asset details">
            {(['versions', 'reviews', 'approvals'] as AssetTab[]).map(name => (
              <button key={name} className={tab === name ? styles.active : ''} onClick={() => setTab(name)}>{capitalize(name)}</button>
            ))}
          </nav>
          {tab === 'versions' && asset.versions.map(version => (
            <article className={styles.row} key={version.id}>
              <div className={styles.toolbar}>
                <strong>Version {version.versionNumber}</strong>
                <div className={styles.actions}>
                  {data.permissions.includes('asset.upload') && !version.isCurrent &&
                    <button onClick={() => setSwitchVersion({ asset, versionId: version.id, versionNumber: version.versionNumber })}>Make current</button>}
                  {data.permissions.includes('asset.approve') && !version.isApproved &&
                    <button onClick={() => setApproval({ asset, versionId: version.id, versionNumber: version.versionNumber })}>Approve</button>}
                </div>
              </div>
              <p>{version.originalFilename}</p>
              <small>{version.isCurrent ? 'Current · ' : ''}{version.isApproved ? 'Approved · ' : ''}{new Date(version.uploadedAt).toLocaleString()}</small>
            </article>
          ))}
          {tab === 'reviews' && asset.reviews.map(review =>
            <ReviewRow key={review.id} review={review} data={data} spreadId={spreadId} runAction={runAction} />)}
          {tab === 'approvals' && asset.approvals.map(item => (
            <article className={styles.row} key={item.id}>
              <div className={styles.toolbar}>
                <strong>{item.approvalType} · {item.decision}</strong>
                {data.permissions.includes('asset.approve') && !item.revokedAt &&
                  <button className={styles.dangerButton} onClick={() => setRevocation({ id: item.id, label: `${item.approvalType} approval` })}>Revoke</button>}
              </div>
              <p>{item.decisionReason}</p>
              {item.revokedAt && <p className={styles.danger}>Revoked: {item.revocationReason}</p>}
            </article>
          ))}
        </>}
      </div>

      {uploadAsset && <UploadVersionModal asset={uploadAsset} onClose={() => setUploadAsset(null)}
        onSubmit={async input => {
          const ok = await runAction(async () => {
            const upload = await call<{ signedUrl: string; storagePath: string }>(`/api/v1/assets/${uploadAsset.id}/upload-url`, {
              method: 'POST', body: JSON.stringify({ filename: input.file.name, contentType: input.file.type || 'application/octet-stream' }),
            });
            const response = await fetch(upload.signedUrl, { method: 'PUT', headers: { 'Content-Type': input.file.type || 'application/octet-stream' }, body: input.file });
            if (!response.ok) throw new Error('The version file could not be uploaded.');
            await call(`/api/v1/assets/${uploadAsset.id}/versions`, { method: 'POST', body: JSON.stringify({
              originalFilename: input.file.name, storagePath: upload.storagePath, fileSizeBytes: input.file.size,
              mimeType: input.file.type || null, changeSummary: input.changeSummary, makeCurrent: input.makeCurrent,
            }) });
          }, 'New asset version uploaded successfully.');
          if (ok) setUploadAsset(null); return ok;
        }} />}
      {switchVersion && <ReasonConfirmationModal title={`Make version ${switchVersion.versionNumber} current`}
        description="This changes the working version without deleting or overwriting any version history."
        confirmLabel="Make current" fieldLabel="Reason for switching" onClose={() => setSwitchVersion(null)}
        onSubmit={async reason => {
          const ok = await runAction(() => call(`/api/v1/assets/${switchVersion.asset.id}/versions/${switchVersion.versionId}/current`, {
            method: 'POST', body: JSON.stringify({ reason }),
          }), `Version ${switchVersion.versionNumber} is now current.`);
          if (ok) setSwitchVersion(null); return ok;
        }} />}
      {reviewAsset && <ReviewRequestModal asset={reviewAsset} data={data} onClose={() => setReviewAsset(null)}
        onSubmit={async input => {
          const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/reviews`, { method: 'POST', body: JSON.stringify(input) }), 'Review request created successfully.');
          if (ok) setReviewAsset(null); return ok;
        }} />}
      {approval && <ApproveVersionModal versionNumber={approval.versionNumber} onClose={() => setApproval(null)}
        onSubmit={async input => {
          const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/assets/${approval.asset.id}/versions/${approval.versionId}/approve`, { method: 'POST', body: JSON.stringify(input) }), `Version ${approval.versionNumber} approved successfully.`);
          if (ok) setApproval(null); return ok;
        }} />}
      {revocation && <ReasonConfirmationModal title="Revoke approval" description={`This will revoke the active ${revocation.label} and return the asset to changes requested.`}
        confirmLabel="Revoke approval" fieldLabel="Revocation reason" destructive onClose={() => setRevocation(null)}
        onSubmit={async reason => {
          const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/approvals/${revocation.id}/revoke`, { method: 'POST', body: JSON.stringify({ revocationReason: reason }) }), 'Approval revoked successfully.');
          if (ok) setRevocation(null); return ok;
        }} />}
    </section>
  );
}

function ReviewRow({ review, data, spreadId, runAction }: { review: AssetReview; data: SpreadManagerData; spreadId: string; runAction: (a: () => Promise<unknown>, s: string) => Promise<boolean> }) {
  const [completeOpen, setCompleteOpen] = useState(false);
  const [resolveComment, setResolveComment] = useState<{ id: string; comment: string } | null>(null);
  return <article className={styles.row}>
    <div className={styles.toolbar}>
      <strong>{review.reviewType} · {review.status}</strong>
      {review.status === 'Open' && data.permissions.includes('review.complete') && <button onClick={() => setCompleteOpen(true)}>Complete review</button>}
    </div>
    <p>{review.reviewer?.displayName ?? 'Unassigned'}</p>
    {review.summary && <p>{review.summary}</p>}
    {review.comments.map(comment => <blockquote key={comment.id}>
      <div className={styles.toolbar}>
        <span><strong>{comment.severity}:</strong> {comment.comment}</span>
        {!comment.isResolved && comment.severity === 'Required Change' && data.permissions.includes('review.resolve_comment') &&
          <button onClick={() => setResolveComment({ id: comment.id, comment: comment.comment })}>Resolve</button>}
      </div>
      {comment.isResolved && <small>Resolved{comment.resolutionNote ? `: ${comment.resolutionNote}` : ''}</small>}
    </blockquote>)}
    {completeOpen && <CompleteReviewModal review={review} onClose={() => setCompleteOpen(false)} onSubmit={async input => {
      const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/reviews/${review.id}/complete`, { method: 'POST', body: JSON.stringify(input) }), 'Review completed successfully.');
      if (ok) setCompleteOpen(false); return ok;
    }} />}
    {resolveComment && <ReasonConfirmationModal title="Resolve required change" description={resolveComment.comment} confirmLabel="Mark resolved" fieldLabel="Resolution note" onClose={() => setResolveComment(null)}
      onSubmit={async note => {
        const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/review-comments/${resolveComment.id}/resolve`, { method: 'POST', body: JSON.stringify({ resolutionNote: note }) }), 'Required-change comment resolved.');
        if (ok) setResolveComment(null); return ok;
      }} />}
  </article>;
}

function Characters({ data }: { data: SpreadManagerData }) {
  return <section>{data.characters.length ? data.characters.map(character => <article className={styles.row} key={character.appearanceId}>
    <strong>{character.name}</strong><p>{character.roleInScene || 'No scene role.'}</p><small>{character.continuityNotes || 'No continuity notes.'}</small>
  </article>) : <p className={styles.empty}>No character appearances are linked to this spread.</p>}</section>;
}

function Tasks({ data, spreadId, runAction }: { data: SpreadManagerData; spreadId: string; runAction: (a: () => Promise<unknown>, s: string) => Promise<boolean> }) {
  const [editing, setEditing] = useState<SpreadTask | null>(null);
  return <section>
    {data.tasks.length ? data.tasks.map(task => <article className={styles.row} key={task.id}>
      <div className={styles.toolbar}><strong>{task.title}</strong>{data.permissions.includes('task.edit') && <button onClick={() => setEditing(task)}>Edit task</button>}</div>
      <p>{task.ownerName || 'Unassigned'} · {task.status} · {task.priority}</p>
      <small>{task.dueDate ? `Due ${task.dueDate}` : 'No due date'}</small>
      {task.blockedReason && <p className={styles.danger}>Blocked: {task.blockedReason}</p>}
    </article>) : <p className={styles.empty}>No tasks are linked to this spread.</p>}
    {editing && <TaskModal task={editing} users={data.users} onClose={() => setEditing(null)} onSubmit={async input => {
      const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/tasks/${editing.id}`, { method: 'PATCH', body: JSON.stringify(input) }), 'Task updated successfully.');
      if (ok) setEditing(null); return ok;
    }} />}
  </section>;
}

function Decisions({ data, spreadId, runAction }: { data: SpreadManagerData; spreadId: string; runAction: (a: () => Promise<unknown>, s: string) => Promise<boolean> }) {
  const [approve, setApprove] = useState<SpreadDecision | null>(null);
  const [supersede, setSupersede] = useState<SpreadDecision | null>(null);
  return <section>
    {data.decisions.length ? data.decisions.map(decision => <article className={styles.row} key={decision.id}>
      <div className={styles.toolbar}>
        <strong>{decision.decisionCode} · {decision.title}</strong>
        <div className={styles.actions}>
          {decision.status !== 'Approved' && data.permissions.includes('decision.approve') && <button onClick={() => setApprove(decision)}>Approve</button>}
          {decision.status === 'Approved' && !decision.isSuperseded && data.permissions.includes('decision.approve') && <button className={styles.dangerButton} onClick={() => setSupersede(decision)}>Supersede</button>}
        </div>
      </div>
      <p>{decision.finalDecision}</p><small>{decision.status} · {decision.decisionOwnerName || 'No owner'}</small>
    </article>) : <p className={styles.empty}>No decisions are recorded for this spread.</p>}
    {approve && <ConfirmationModal title="Approve decision" description={`Approve “${approve.title}” as the formal decision for this spread?`} confirmLabel="Approve decision" onClose={() => setApprove(null)} onConfirm={async () => {
      const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/decisions/${approve.id}/approve`, { method: 'POST', body: '{}' }), 'Decision approved successfully.');
      if (ok) setApprove(null); return ok;
    }} />}
    {supersede && <SupersedeDecisionModal decision={supersede} onClose={() => setSupersede(null)} onSubmit={async input => {
      const ok = await runAction(() => call(`/api/v1/spreads/${spreadId}/decisions/${supersede.id}/supersede`, { method: 'POST', body: JSON.stringify(input) }), 'Decision superseded successfully.');
      if (ok) setSupersede(null); return ok;
    }} />}
  </section>;
}


function UploadVersionModal({ asset, onClose, onSubmit }: { asset: Asset; onClose: () => void; onSubmit: (input: { file: File; changeSummary: string | null; makeCurrent: boolean }) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const form = new FormData(event.currentTarget); const file = form.get('file');
    const next: FieldErrors = {}; if (!(file instanceof File) || file.size === 0) next.file = 'Choose a version file.';
    if (Object.keys(next).length) return setErrors(next);
    setBusy(true); const ok = await onSubmit({ file: file as File, changeSummary: nullable(form, 'changeSummary'), makeCurrent: form.get('makeCurrent') === 'on' });
    setBusy(false); if (!ok) setErrors({ form: 'The version was not uploaded.' });
  }
  return <Modal title="Upload new version" description={`Add an immutable version to ${asset.title}.`} onClose={onClose} busy={busy}>
    <form className={styles.modalForm} onSubmit={submit} noValidate>
      <Field label="Version file" error={errors.file}><input name="file" type="file" /></Field>
      <Field label="Change summary"><textarea name="changeSummary" placeholder="What changed in this version?" /></Field>
      <label><input name="makeCurrent" type="checkbox" defaultChecked /> Make this the current version</label>
      <FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Upload version" />
    </form>
  </Modal>;
}

function ReviewRequestModal({ asset, data, onClose, onSubmit }: { asset: Asset; data: SpreadManagerData; onClose: () => void; onSubmit: (input: unknown) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const form = new FormData(event.currentTarget);
    const input = { assetId: asset.id, assetVersionId: text(form, 'version'), assignedReviewer: text(form, 'reviewer'), reviewType: text(form, 'type').trim(), instructions: nullable(form, 'instructions'), dueDate: nullable(form, 'dueDate') };
    const next: FieldErrors = {};
    if (!input.assetVersionId) next.version = 'Select an asset version.';
    if (!input.assignedReviewer) next.reviewer = 'Select a reviewer.';
    if (input.reviewType.length < 2) next.type = 'Enter a review type.';
    if (input.dueDate && input.dueDate < new Date().toISOString().slice(0, 10)) next.dueDate = 'Due date cannot be in the past.';
    if (Object.keys(next).length) return setErrors(next);
    setBusy(true); const ok = await onSubmit(input); setBusy(false); if (!ok) setErrors({ form: 'The review request was not created. Check the page message and try again.' });
  }
  return <Modal title="Request review" description={`Send a version of ${asset.title} to a reviewer.`} onClose={onClose} busy={busy}>
    <form className={styles.modalForm} onSubmit={submit} noValidate>
      <Field label="Asset version" error={errors.version}><select name="version" defaultValue={asset.currentVersionId ?? asset.versions[0]?.id ?? ''}><option value="">Select version</option>{asset.versions.map(v => <option key={v.id} value={v.id}>Version {v.versionNumber}</option>)}</select></Field>
      <Field label="Reviewer" error={errors.reviewer}><select name="reviewer" defaultValue=""><option value="">Select reviewer</option>{data.users.map(u => <option key={u.id} value={u.id}>{u.displayName}</option>)}</select></Field>
      <Field label="Review type" error={errors.type}><input name="type" placeholder="Editorial, art, design…" /></Field>
      <Field label="Due date" error={errors.dueDate}><input name="dueDate" type="date" /></Field>
      <Field label="Instructions"><textarea name="instructions" placeholder="What should the reviewer check?" /></Field>
      <FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Send review request" />
    </form>
  </Modal>;
}

function CompleteReviewModal({ review, onClose, onSubmit }: { review: AssetReview; onClose: () => void; onSubmit: (input: unknown) => Promise<boolean> }) {
  const [comments, setComments] = useState([{ comment: '', severity: 'Required Change' }]);
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); const form = new FormData(event.currentTarget); const recommendation = text(form, 'recommendation');
    const clean = comments.map(c => ({ ...c, comment: c.comment.trim() })).filter(c => c.comment);
    const next: FieldErrors = {};
    if (!recommendation) next.recommendation = 'Select a recommendation.';
    if (comments.some((c, i) => c.comment.trim() === '' && i < comments.length - 1)) next.comments = 'Remove blank comments or enter comment text.';
    if (recommendation === 'Changes Requested' && !clean.some(c => c.severity === 'Required Change')) next.comments = 'Changes Requested requires at least one required-change comment.';
    if (Object.keys(next).length) return setErrors(next);
    setBusy(true); const ok = await onSubmit({ summary: nullable(form, 'summary'), decisionRecommendation: recommendation, comments: clean }); setBusy(false); if (!ok) setErrors({ form: 'The review could not be completed.' });
  }
  return <Modal title="Complete review" description={`${review.reviewType} review`} onClose={onClose} busy={busy}>
    <form className={styles.modalForm} onSubmit={submit} noValidate>
      <Field label="Review summary"><textarea name="summary" placeholder="Summarise your findings." /></Field>
      <Field label="Recommendation" error={errors.recommendation}><select name="recommendation" defaultValue=""><option value="">Select recommendation</option><option>Approved</option><option>Changes Requested</option><option>No Decision</option></select></Field>
      <fieldset className={styles.fieldset}><legend>Comments</legend>{comments.map((comment, index) => <div className={styles.commentEditor} key={index}><select aria-label={`Comment ${index + 1} severity`} value={comment.severity} onChange={e => setComments(items => items.map((item, i) => i === index ? { ...item, severity: e.target.value } : item))}><option>Required Change</option><option>Suggestion</option><option>Question</option></select><input aria-label={`Comment ${index + 1}`} value={comment.comment} onChange={e => setComments(items => items.map((item, i) => i === index ? { ...item, comment: e.target.value } : item))} placeholder="Add a specific comment" />{comments.length > 1 && <button type="button" className={styles.secondaryButton} onClick={() => setComments(items => items.filter((_, i) => i !== index))}>Remove</button>}</div>)}
      <button type="button" className={styles.secondaryButton} onClick={() => setComments(items => [...items, { comment: '', severity: 'Suggestion' }])}>Add comment</button><FieldError message={errors.comments} /></fieldset>
      <FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Complete review" />
    </form>
  </Modal>;
}

function ApproveVersionModal({ versionNumber, onClose, onSubmit }: { versionNumber: number; onClose: () => void; onSubmit: (input: unknown) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const form = new FormData(event.currentTarget); const input = { approvalType: text(form, 'approvalType').trim(), decisionReason: text(form, 'decisionReason').trim() }; const next: FieldErrors = {}; if (!input.approvalType) next.approvalType = 'Enter an approval type.'; if (input.decisionReason.length < 5) next.decisionReason = 'Provide a meaningful approval reason.'; if (Object.keys(next).length) return setErrors(next); setBusy(true); const ok = await onSubmit(input); setBusy(false); if (!ok) setErrors({ form: 'The version was not approved.' }); }
  return <Modal title={`Approve version ${versionNumber}`} description="Approval is audit-sensitive and will make this the approved current version." onClose={onClose} busy={busy}>
    <form className={styles.modalForm} onSubmit={submit} noValidate><Field label="Approval type" error={errors.approvalType}><input name="approvalType" defaultValue="Production" /></Field><Field label="Approval reason" error={errors.decisionReason}><textarea name="decisionReason" placeholder="Explain why this version is ready for approval." /></Field><FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Approve version" /></form>
  </Modal>;
}

function TaskModal({ task, users, onClose, onSubmit }: { task: SpreadTask; users: SpreadManagerData['users']; onClose: () => void; onSubmit: (input: unknown) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const form = new FormData(event.currentTarget); const input = { title: text(form, 'title').trim(), description: nullable(form, 'description'), status: text(form, 'status'), priority: text(form, 'priority'), assignedTo: nullable(form, 'assignedTo'), dueDate: nullable(form, 'dueDate'), blockedReason: nullable(form, 'blockedReason') }; const next: FieldErrors = {}; if (input.title.length < 2) next.title = 'Task title must contain at least two characters.'; if (!input.status) next.status = 'Select a status.'; if (!input.priority) next.priority = 'Select a priority.'; if (input.status === 'Blocked' && !input.blockedReason) next.blockedReason = 'Explain why the task is blocked.'; if (Object.keys(next).length) return setErrors(next); setBusy(true); const ok = await onSubmit(input); setBusy(false); if (!ok) setErrors({ form: 'The task was not updated.' }); }
  return <Modal title="Edit task" description="Update assignment, timing, priority, and workflow status." onClose={onClose} busy={busy}><form className={styles.modalForm} onSubmit={submit} noValidate><Field label="Title" error={errors.title}><input name="title" defaultValue={task.title} /></Field><Field label="Description"><textarea name="description" defaultValue={task.description ?? ''} /></Field><div className={styles.twoColumn}><Field label="Status" error={errors.status}><select name="status" defaultValue={task.status}><option>Not Started</option><option>In Progress</option><option>Blocked</option><option>Completed</option><option>Cancelled</option></select></Field><Field label="Priority" error={errors.priority}><select name="priority" defaultValue={task.priority}><option>Critical</option><option>High</option><option>Medium</option><option>Low</option></select></Field></div><Field label="Assigned to"><select name="assignedTo" defaultValue={task.assignedTo ?? ''}><option value="">Unassigned</option>{users.map(user => <option key={user.id} value={user.id}>{user.displayName}</option>)}</select></Field><Field label="Due date"><input name="dueDate" type="date" defaultValue={task.dueDate ?? ''} /></Field><Field label="Blocked reason" error={errors.blockedReason}><textarea name="blockedReason" defaultValue={task.blockedReason ?? ''} placeholder="Required when status is Blocked" /></Field><FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Save task" /></form></Modal>;
}

function SupersedeDecisionModal({ decision, onClose, onSubmit }: { decision: SpreadDecision; onClose: () => void; onSubmit: (input: unknown) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [errors, setErrors] = useState<FieldErrors>({});
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const form = new FormData(event.currentTarget); const input = { decisionCode: text(form, 'decisionCode').trim(), title: text(form, 'title').trim(), context: nullable(form, 'context'), optionsConsidered: [], finalDecision: text(form, 'finalDecision').trim(), reason: text(form, 'reason').trim() }; const next: FieldErrors = {}; if (!input.decisionCode) next.decisionCode = 'Enter a unique decision code.'; if (!input.title) next.title = 'Enter a title.'; if (input.finalDecision.length < 5) next.finalDecision = 'Describe the replacement decision.'; if (input.reason.length < 5) next.reason = 'Explain why the previous decision is being superseded.'; if (Object.keys(next).length) return setErrors(next); setBusy(true); const ok = await onSubmit(input); setBusy(false); if (!ok) setErrors({ form: 'The decision was not superseded.' }); }
  return <Modal title="Supersede decision" description={`This preserves ${decision.decisionCode} in the audit history and creates a replacement decision.`} onClose={onClose} busy={busy}><form className={styles.modalForm} onSubmit={submit} noValidate><Field label="New decision code" error={errors.decisionCode}><input name="decisionCode" placeholder="DEC-012" /></Field><Field label="Title" error={errors.title}><input name="title" defaultValue={decision.title} /></Field><Field label="Context"><textarea name="context" defaultValue={decision.context ?? ''} /></Field><Field label="Replacement decision" error={errors.finalDecision}><textarea name="finalDecision" /></Field><Field label="Reason for superseding" error={errors.reason}><textarea name="reason" /></Field><FormError message={errors.form} /><ModalActions onCancel={onClose} busy={busy} submitLabel="Supersede decision" destructive /></form></Modal>;
}

function LockSpreadModal({ open, locked, onClose, onSubmit }: { open: boolean; locked: boolean; onClose: () => void; onSubmit: (reason: string) => Promise<boolean> }) {
  if (!open) return null;
  return <ReasonConfirmationModal title={locked ? 'Unlock spread' : 'Lock spread'} description={locked ? 'Unlocking permits authorised users to change spread production records again.' : 'Locking prevents edits to this spread until it is explicitly unlocked.'} confirmLabel={locked ? 'Unlock spread' : 'Lock spread'} fieldLabel={locked ? 'Unlock reason' : 'Lock reason'} destructive={!locked} onClose={onClose} onSubmit={onSubmit} />;
}

function ReasonConfirmationModal({ title, description, fieldLabel, confirmLabel, destructive = false, onClose, onSubmit }: { title: string; description: string; fieldLabel: string; confirmLabel: string; destructive?: boolean; onClose: () => void; onSubmit: (reason: string) => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); const reason = text(new FormData(event.currentTarget), 'reason').trim(); if (reason.length < 5) return setError('Enter a reason of at least five characters.'); setBusy(true); const ok = await onSubmit(reason); setBusy(false); if (!ok) setError('The action was not completed.'); }
  return <Modal title={title} description={description} onClose={onClose} busy={busy}><form className={styles.modalForm} onSubmit={submit} noValidate><Field label={fieldLabel} error={error}><textarea name="reason" autoFocus /></Field><ModalActions onCancel={onClose} busy={busy} submitLabel={confirmLabel} destructive={destructive} /></form></Modal>;
}

function ConfirmationModal({ title, description, confirmLabel, onClose, onConfirm }: { title: string; description: string; confirmLabel: string; onClose: () => void; onConfirm: () => Promise<boolean> }) {
  const [busy, setBusy] = useState(false); return <Modal title={title} description={description} onClose={onClose} busy={busy}><div className={styles.modalActions}><button type="button" className={styles.secondaryButton} onClick={onClose} disabled={busy}>Cancel</button><button type="button" onClick={async () => { setBusy(true); await onConfirm(); setBusy(false); }} disabled={busy}>{busy ? 'Working…' : confirmLabel}</button></div></Modal>;
}

function Modal({ title, description, children, onClose, busy }: { title: string; description?: string; children: ReactNode; onClose: () => void; busy?: boolean }) {
  const dialog = useRef<HTMLDivElement>(null);
  useEffect(() => { const before = document.activeElement as HTMLElement | null; dialog.current?.focus(); const key = (event: KeyboardEvent) => { if (event.key === 'Escape' && !busy) onClose(); }; document.addEventListener('keydown', key); return () => { document.removeEventListener('keydown', key); before?.focus(); }; }, [onClose, busy]);
  return <div className={styles.modalBackdrop} role="presentation" onMouseDown={event => { if (event.target === event.currentTarget && !busy) onClose(); }}><div className={styles.modal} role="dialog" aria-modal="true" aria-labelledby="modal-title" tabIndex={-1} ref={dialog}><div className={styles.modalHeader}><div><h2 id="modal-title">{title}</h2>{description && <p>{description}</p>}</div><button type="button" className={styles.iconButton} aria-label="Close dialog" onClick={onClose} disabled={busy}>×</button></div>{children}</div></div>;
}

function Field({ label, error, children }: { label: string; error?: string; children: ReactNode }) { return <label className={styles.field}><span>{label}</span>{children}<FieldError message={error} /></label>; }
function FieldError({ message }: { message?: string }) { return message ? <small className={styles.fieldError} role="alert">{message}</small> : null; }
function FormError({ message }: { message?: string }) { return message ? <div className={styles.formError} role="alert">{message}</div> : null; }
function ModalActions({ onCancel, busy, submitLabel, destructive = false }: { onCancel: () => void; busy: boolean; submitLabel: string; destructive?: boolean }) { return <div className={styles.modalActions}><button type="button" className={styles.secondaryButton} onClick={onCancel} disabled={busy}>Cancel</button><button type="submit" className={destructive ? styles.dangerButton : ''} disabled={busy}>{busy ? 'Working…' : submitLabel}</button></div>; }
function NoticeBanner({ notice, onDismiss }: { notice: Exclude<Notice, null>; onDismiss: () => void }) { return <div className={notice.kind === 'success' ? styles.success : styles.error} role={notice.kind === 'error' ? 'alert' : 'status'}><span>{notice.message}</span><button type="button" onClick={onDismiss} aria-label="Dismiss message">×</button></div>; }
function text(form: FormData, name: string) { return String(form.get(name) ?? ''); }
function nullable(form: FormData, name: string) { const value = text(form, name).trim(); return value || null; }
function capitalize(value: string) { return value.charAt(0).toUpperCase() + value.slice(1); }
