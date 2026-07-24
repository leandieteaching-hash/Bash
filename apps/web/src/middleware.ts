import {NextRequest, NextResponse} from 'next/server';
import {ACCESS_COOKIE, SESSION_COOKIE} from '@/lib/auth/config';

const publicRoutes = ['/login','/forgot-password','/reset-password','/verify-email','/session-expired'];
export function middleware(request: NextRequest) {
  const {pathname}=request.nextUrl;
  if (pathname.startsWith('/api/') || pathname.startsWith('/_next/') || publicRoutes.includes(pathname)) return NextResponse.next();
  const authenticated=Boolean(request.cookies.get(ACCESS_COOKIE)?.value&&request.cookies.get(SESSION_COOKIE)?.value);
  if (!authenticated) {const login=new URL('/login',request.url);login.searchParams.set('returnTo',pathname);return NextResponse.redirect(login)}
  return NextResponse.next();
}
export const config={matcher:['/((?!favicon.ico|robots.txt|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)']};
