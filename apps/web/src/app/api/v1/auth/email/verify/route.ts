import {NextResponse} from 'next/server';
import {verifyEmailSchema} from '@/lib/auth/validation';
import {resendVerification} from '@/lib/auth/service';
import {clientAddress, consumeRateLimit} from '@/lib/auth/rate-limit';

export async function POST(request: Request) {
  const requestId = request.headers.get('x-request-id') ?? crypto.randomUUID();
  const parsed = verifyEmailSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({error: {code: 'INVALID_REQUEST'}, requestId}, {status: 400});
  const rate = consumeRateLimit(`verify:${clientAddress(request)}:${parsed.data.email.toLowerCase()}`, 4, 60 * 60 * 1000);
  if (!rate.allowed) return NextResponse.json({error: {code: 'RATE_LIMITED'}, requestId}, {status: 429, headers: {'retry-after': String(rate.retryAfterSeconds)}});
  const origin = new URL(request.url).origin;
  await resendVerification(parsed.data.email, `${origin}/login?verified=1`).catch(() => undefined);
  return NextResponse.json({data: {accepted: true}, requestId}, {status: 202});
}
