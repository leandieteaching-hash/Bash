import path from 'node:path';
import { test, expect } from './fixtures/workflow';
import { assetVersions, db, expectEventually, latestReview } from './support/database';

const requiredChange = `E2E required change ${Date.now()}`;
const replacementCode = `E2E-${Date.now()}`;

test.describe.serial('Spread Manager transactional user journey', () => {
  test('Upload Version 2 without overwriting Version 1', async ({ workflow }) => {
    const before = await assetVersions(workflow.env.E2E_ASSET_ID);
    expect(before).toHaveLength(1);

    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Upload version' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Upload new version' });
    await dialog.getByLabel('Version file').setInputFiles(path.join(__dirname, 'assets/version-2.svg'));
    await dialog.getByLabel('Change summary').fill('Second illustration version from Playwright');
    await dialog.getByRole('button', { name: 'Upload version' }).click();
    await workflow.expectSuccess('New asset version uploaded successfully.');

    await expectEventually(() => assetVersions(workflow.env.E2E_ASSET_ID), versions => {
      expect(versions).toHaveLength(2);
      expect(versions.map(v => v.version_number)).toEqual([1, 2]);
      expect(versions[0].storage_path).not.toBe(versions[1].storage_path);
      expect(versions[1].is_current).toBe(true);
    });
    await expect(workflow.page.getByText('Version 2', { exact: true })).toBeVisible();
  });

  test('Request Review', async ({ workflow }) => {
    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Request review' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Request review' });
    await dialog.getByLabel('Reviewer').selectOption(workflow.env.E2E_REVIEWER_ID);
    await dialog.getByLabel('Review type').fill('E2E art review');
    await dialog.getByLabel('Instructions').fill('Check character consistency and composition.');
    await dialog.getByRole('button', { name: 'Send review request' }).click();
    await workflow.expectSuccess('Review request created successfully.');

    const review = await latestReview(workflow.env.E2E_ASSET_ID);
    expect(review.status).toBe('Open');
    expect(review.asset_version_id).toBe((await assetVersions(workflow.env.E2E_ASSET_ID))[1].id);
  });

  test('Add Required Change by completing the review', async ({ workflow }) => {
    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Reviews' }).click();
    await workflow.page.getByRole('button', { name: 'Complete review' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Complete review' });
    await dialog.getByLabel('Review summary').fill('One production correction remains.');
    await dialog.getByLabel('Recommendation').selectOption('Changes Requested');
    await dialog.getByLabel('Comment 1 severity').selectOption('Required Change');
    await dialog.getByLabel('Comment 1').fill(requiredChange);
    await dialog.getByRole('button', { name: 'Complete review' }).click();
    await workflow.expectSuccess('Review completed successfully.');

    await expectEventually(() => latestReview(workflow.env.E2E_ASSET_ID), review => {
      expect(review.status).toBe('Completed');
      expect(review.completed_at).not.toBeNull();
      expect(review.review_comments).toEqual(expect.arrayContaining([
        expect.objectContaining({ severity: 'Required Change', is_resolved: false }),
      ]));
    });
  });

  test('Resolve Comment', async ({ workflow }) => {
    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Reviews' }).click();
    const comment = workflow.page.locator('blockquote').filter({ hasText: requiredChange });
    await comment.getByRole('button', { name: 'Resolve' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Resolve required change' });
    await dialog.getByLabel('Resolution note').fill('Corrected in Version 2 and verified.');
    await dialog.getByRole('button', { name: 'Mark resolved' }).click();
    await workflow.expectSuccess('Required-change comment resolved.');

    await expectEventually(() => latestReview(workflow.env.E2E_ASSET_ID), review => {
      const required = review.review_comments.find((item: any) => item.severity === 'Required Change');
      expect(required.is_resolved).toBe(true);
      expect(required.resolution_note).toContain('verified');
    });
  });

  test('Approve Version', async ({ workflow }) => {
    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Versions' }).click();
    const version2 = workflow.page.locator('article').filter({ hasText: 'Version 2' });
    await version2.getByRole('button', { name: 'Approve' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Approve version 2' });
    await dialog.getByLabel('Approval reason').fill('Required change resolved and final artwork verified.');
    await dialog.getByRole('button', { name: 'Approve version' }).click();
    await workflow.expectSuccess('Version 2 approved successfully.');

    await expectEventually(() => assetVersions(workflow.env.E2E_ASSET_ID), versions => {
      expect(versions.find(v => v.version_number === 2)?.is_approved).toBe(true);
    });
  });

  test('Switch Current Version after revoking the active approval', async ({ workflow }) => {
    await workflow.selectAsset();
    await workflow.page.getByRole('button', { name: 'Approvals' }).click();
    await workflow.page.getByRole('button', { name: 'Revoke' }).click();
    let dialog = workflow.page.getByRole('dialog', { name: 'Revoke approval' });
    await dialog.getByLabel('Revocation reason').fill('E2E verifies version switching after revocation.');
    await dialog.getByRole('button', { name: 'Revoke approval' }).click();
    await workflow.expectSuccess('Approval revoked successfully.');

    await workflow.page.getByRole('button', { name: 'Versions' }).click();
    const version1 = workflow.page.locator('article').filter({ hasText: 'Version 1' });
    await version1.getByRole('button', { name: 'Make current' }).click();
    dialog = workflow.page.getByRole('dialog', { name: 'Make version 1 current' });
    await dialog.getByLabel('Reason for switching').fill('Regression comparison for final production check.');
    await dialog.getByRole('button', { name: 'Make current' }).click();
    await workflow.expectSuccess('Version 1 is now current.');

    await expectEventually(() => assetVersions(workflow.env.E2E_ASSET_ID), versions => {
      expect(versions.find(v => v.version_number === 1)?.is_current).toBe(true);
      expect(versions.find(v => v.version_number === 2)?.is_current).toBe(false);
    });
  });

  test('Lock Spread', async ({ workflow }) => {
    await workflow.page.getByRole('button', { name: 'Lock spread' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Lock spread' });
    await dialog.getByLabel('Lock reason').fill('E2E production freeze verification.');
    await dialog.getByRole('button', { name: 'Lock spread' }).click();
    await workflow.expectSuccess('Spread locked successfully.');
    await expect(workflow.page.getByText('Locked', { exact: true })).toBeVisible();

    await expectEventually(async () => {
      const { data, error } = await db.from('spreads').select('locked_at').eq('id', workflow.env.E2E_SPREAD_ID).single();
      if (error) throw error; return data.locked_at;
    }, lockedAt => expect(lockedAt).not.toBeNull());
  });

  test('Unlock Spread', async ({ workflow }) => {
    await workflow.page.getByRole('button', { name: 'Unlock spread' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Unlock spread' });
    await dialog.getByLabel('Unlock reason').fill('E2E production freeze completed.');
    await dialog.getByRole('button', { name: 'Unlock spread' }).click();
    await workflow.expectSuccess('Spread unlocked successfully.');
    await expect(workflow.page.getByText('Locked', { exact: true })).toHaveCount(0);
  });

  test('Supersede Decision', async ({ workflow }) => {
    await workflow.page.getByRole('button', { name: 'Decisions' }).click();
    const approved = workflow.page.locator('article').filter({ hasText: process.env.E2E_DECISION_TITLE ?? 'Approved' }).first();
    await approved.getByRole('button', { name: 'Supersede' }).click();
    const dialog = workflow.page.getByRole('dialog', { name: 'Supersede decision' });
    await dialog.getByLabel('New decision code').fill(replacementCode);
    await dialog.getByLabel('Replacement decision').fill('Use the revised E2E production direction.');
    await dialog.getByLabel('Reason for superseding').fill('Updated after final cross-functional review.');
    await dialog.getByRole('button', { name: 'Supersede decision' }).click();
    await workflow.expectSuccess('Decision superseded successfully.');

    await expectEventually(async () => {
      const { data, error } = await db.from('spread_decisions')
        .select('id,decision_code,status,is_superseded,supersedes_decision_id')
        .or(`id.eq.${workflow.env.E2E_APPROVED_DECISION_ID},decision_code.eq.${replacementCode}`);
      if (error) throw error; return data;
    }, decisions => {
      expect(decisions.find(d => d.id === workflow.env.E2E_APPROVED_DECISION_ID)?.is_superseded).toBe(true);
      expect(decisions.find(d => d.decision_code === replacementCode)?.supersedes_decision_id).toBe(workflow.env.E2E_APPROVED_DECISION_ID);
    });
  });
});
