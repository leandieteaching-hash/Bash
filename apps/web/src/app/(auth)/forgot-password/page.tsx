import Link from 'next/link';import {AuthCard} from '@/components/auth/AuthCard';import {ForgotPasswordForm} from '@/components/auth/ForgotPasswordForm';
export default function Page(){return <AuthCard title="Reset your password" description="We will send a secure recovery link to your email address." footer={<Link href="/login">Return to sign in</Link>}><ForgotPasswordForm/></AuthCard>}
