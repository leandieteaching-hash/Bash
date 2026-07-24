import { test as base, expect } from '@playwright/test';
import { e2eEnv } from '../support/env';

export const test = base.extend<{ workflow: ReturnType<typeof createWorkflow> }>({
  workflow: async ({ page }, use) => {
    const env = e2eEnv();
    const workflow = createWorkflow(page, env);
    await workflow.open();
    await use(workflow);
  },
});

function createWorkflow(page: import('@playwright/test').Page, env: ReturnType<typeof e2eEnv>) {
  const spreadPath = process.env.E2E_SPREAD_MANAGER_PATH ?? `/spreads/${env.E2E_SPREAD_ID}/manager`;
  return {
    page,
    env,
    async open() {
      await page.goto(spreadPath);
      await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
      await expect(page.getByText('Live collaboration')).toBeVisible({ timeout: 15_000 });
    },
    async selectAsset() {
      const assetButton = page.locator('aside button').filter({ has: page.locator(`text=${process.env.E2E_ASSET_TITLE ?? 'Spread 08'}`) }).first();
      if (await assetButton.count()) await assetButton.click();
    },
    async expectSuccess(message: string | RegExp) {
      await expect(page.getByRole('status').filter({ hasText: message })).toBeVisible();
    },
  };
}

export { expect };
