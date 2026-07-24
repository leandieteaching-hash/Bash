import {Suspense} from 'react';import {AuthCard} from '@/components/auth/AuthCard';import {ResetPasswordForm} from '@/components/auth/ResetPasswordForm';
export default function Page(){return <AuthCard title="Choose a new password" description="Updating your password revokes all existing Studio OS sessions."><Suspense fallback={<p>Loading…</p>}><ResetPasswordForm/></Suspense></AuthCard>}
