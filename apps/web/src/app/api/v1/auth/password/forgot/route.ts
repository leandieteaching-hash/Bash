import {NextResponse} from 'next/server';
import {forgotPasswordSchema} from '@/lib/auth/validation';
import {requestPasswordReset} from '@/lib/auth/service';
import {clientAddress, consumeRateLimit} from '@/lib/auth/rate-limit';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const parsed = forgotPasswordSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({error: {code: 'INVALID_REQUEST'}, requestId}, {status: 400});
  const rate = consumeRateLimit(`password-reset:${clientAddress(request)}:${parsed.data.email.toLowerCase()}`, 4, 60 * 60 * 1000);
  if (!rate.allowed) return NextResponse.json({error: {code: 'RATE_LIMITED'}, requestId}, {status: 429, headers: {'retry-after': String(rate.retryAfterSeconds)}});
  const origin = new URL(request.url).origin;
  await requestPasswordReset(parsed.data.email, `${origin}/reset-password`).catch(() => undefined);
  return NextResponse.json({data: {accepted: true, message: 'If the account exists, a reset link has been sent.'}, requestId}, {status: 202});
}
