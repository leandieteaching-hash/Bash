import {Suspense} from 'react';import {AuthCard} from '@/components/auth/AuthCard';import {LoginForm} from '@/components/auth/LoginForm';
export default function LoginPage(){return <AuthCard title="Welcome back" description="Sign in to your publishing workspace."><Suspense fallback={<p>Loading…</p>}><LoginForm/></Suspense></AuthCard>}
