import Link from 'next/link';import {AuthCard} from '@/components/auth/AuthCard';
export default function Page(){return <AuthCard title="Your session expired" description="For your security, sign in again to continue."><Link className="button buttonPrimary" href="/login">Sign in again</Link></AuthCard>}
