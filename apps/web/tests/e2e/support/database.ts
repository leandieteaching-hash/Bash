import { createClient } from '@supabase/supabase-js';
import { e2eEnv } from './env';

const env = e2eEnv();
export const db = createClient(env.NEXT_PUBLIC_SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export async function expectEventually<T>(load: () => Promise<T>, assertion: (value: T) => void, timeout = 10_000) {
  const deadline = Date.now() + timeout;
  let lastError: unknown;
  while (Date.now() < deadline) {
    try {
      const value = await load();
      assertion(value);
      return;
    } catch (error) {
      lastError = error;
      await new Promise(resolve => setTimeout(resolve, 250));
    }
  }
  throw lastError ?? new Error('Database assertion timed out.');
}

export async function assetVersions(assetId: string) {
  const { data, error } = await db.from('asset_versions')
    .select('id,version_number,original_filename,is_current,is_approved,storage_path')
    .eq('asset_id', assetId).order('version_number');
  if (error) throw error;
  return data;
}

export async function latestReview(assetId: string) {
  const { data, error } = await db.from('review_requests')
    .select('id,status,completed_at,asset_version_id,review_comments(id,severity,is_resolved,resolution_note)')
    .eq('asset_id', assetId).order('created_at', { ascending: false }).limit(1).single();
  if (error) throw error;
  return data;
}
