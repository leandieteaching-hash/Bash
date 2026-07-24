import {NextResponse} from 'next/server';
import {resetPasswordSchema} from '@/lib/auth/validation';
import {updatePassword} from '@/lib/auth/service';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const parsed = resetPasswordSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({error: {code: 'INVALID_REQUEST', details: parsed.error.flatten()}, requestId}, {status: 400});
  try {
    await updatePassword(parsed.data.accessToken, parsed.data.password);
    return NextResponse.json({data: {updated: true}, requestId});
  } catch {
    return NextResponse.json({error: {code: 'INVALID_OR_EXPIRED_RECOVERY_TOKEN'}, requestId}, {status: 400});
  }
}
