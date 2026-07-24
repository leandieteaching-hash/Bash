import Link from 'next/link';import {AuthCard} from '@/components/auth/AuthCard';import {VerifyEmailForm} from '@/components/auth/VerifyEmailForm';
export default function Page(){return <AuthCard title="Verify your email" description="Request a fresh verification message." footer={<Link href="/login">Return to sign in</Link>}><VerifyEmailForm/></AuthCard>}
