import { chromium, type FullConfig } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';
import { mkdir } from 'node:fs/promises';
import { e2eEnv } from './support/env';

export default async function globalSetup(config: FullConfig) {
  const env = e2eEnv();
  const supabase = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.auth.signInWithPassword({ email: env.E2E_USER_EMAIL, password: env.E2E_USER_PASSWORD });
  if (error || !data.session) throw new Error(`E2E sign-in failed: ${error?.message ?? 'No session returned'}`);

  const projectRef = new URL(env.NEXT_PUBLIC_SUPABASE_URL).hostname.split('.')[0];
  const browser = await chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(config.projects[0].use.baseURL as string);
  await page.evaluate(({ key, session }) => localStorage.setItem(key, JSON.stringify(session)), {
    key: `sb-${projectRef}-auth-token`, session: data.session,
  });
  await mkdir('tests/e2e/.auth', { recursive: true });
  await context.storageState({ path: 'tests/e2e/.auth/user.json' });
  await browser.close();
}
