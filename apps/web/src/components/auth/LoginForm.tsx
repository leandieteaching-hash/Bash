'use client';
import Link from 'next/link';
import {useRouter, useSearchParams} from 'next/navigation';
import {useState, type FormEvent} from 'react';

export function LoginForm() {
  const router=useRouter(); const params=useSearchParams();
  const [error,setError]=useState(''); const [pending,setPending]=useState(false);
  async function submit(event:FormEvent<HTMLFormElement>){event.preventDefault();setPending(true);setError('');const form=new FormData(event.currentTarget);const response=await fetch('/api/v1/auth/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:form.get('email'),password:form.get('password'),rememberMe:form.get('rememberMe')==='on'})});const payload=await response.json();setPending(false);if(!response.ok){setError(payload.error?.message??'Unable to sign in.');return}router.replace(params.get('returnTo')||'/dashboard');router.refresh()}
  return <form className="authForm" onSubmit={submit}>
    {params.get('verified')==='1'&&<div className="authNotice success" role="status">Your email address has been verified.</div>}
    {error&&<div className="authNotice danger" role="alert">{error}</div>}
    <label>Email address<input name="email" type="email" autoComplete="email" required/></label>
    <label>Password<input name="password" type="password" autoComplete="current-password" minLength={8} required/></label>
    <div className="authFormRow"><label className="checkbox"><input name="rememberMe" type="checkbox"/> Remember me</label><Link href="/forgot-password">Forgot password?</Link></div>
    <button className="button buttonPrimary" disabled={pending} type="submit">{pending?'Signing in…':'Sign in'}</button>
  </form>;
}
