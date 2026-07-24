import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export type Actor = {
  authUserId: string;
  profileId: string;
  email: string;
  permissions: Set<string>;
};

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: unknown) {
    super(message);
  }
}

export function adminDb(): SupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Supabase server environment variables are missing.');
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export async function requirePermission(permission: string): Promise<Actor> {
  // Replace this adapter with the application's existing server session resolver.
  // The database remains protected by server-side permission checks and RLS.
  const profileId = process.env.STUDIO_DEV_PROFILE_ID;
  const email = process.env.STUDIO_DEV_EMAIL ?? 'developer@local';
  const granted = new Set((process.env.STUDIO_DEV_PERMISSIONS ?? '').split(',').map(x => x.trim()).filter(Boolean));
  if (!profileId) throw new ApiError(401, 'AUTH_REQUIRED', 'No authenticated Studio OS profile was resolved.');
  if (!granted.has(permission)) throw new ApiError(403, 'PERMISSION_DENIED', `Permission required: ${permission}`);
  return { authUserId: profileId, profileId, email, permissions: granted };
}

export function response(data: unknown, status = 200) {
  return Response.json({ data }, { status });
}

export function errorResponse(error: unknown) {
  if (error instanceof ApiError) {
    return Response.json({ error: { code: error.code, message: error.message, details: error.details } }, { status: error.status });
  }
  console.error(error);
  return Response.json({ error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred.' } }, { status: 500 });
}
