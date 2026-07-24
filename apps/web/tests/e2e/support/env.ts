const required = [
  'NEXT_PUBLIC_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY',
  'E2E_USER_EMAIL', 'E2E_USER_PASSWORD', 'E2E_SPREAD_ID', 'E2E_ASSET_ID',
  'E2E_REVIEWER_ID', 'E2E_APPROVED_DECISION_ID',
] as const;

export function e2eEnv() {
  const missing = required.filter(key => !process.env[key]);
  if (missing.length) throw new Error(`Missing E2E environment variables: ${missing.join(', ')}`);
  return Object.fromEntries(required.map(key => [key, process.env[key]!])) as Record<(typeof required)[number], string>;
}
