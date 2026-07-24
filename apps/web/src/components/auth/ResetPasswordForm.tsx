'use client';
import Link from 'next/link';
import {useSearchParams} from 'next/navigation';
import {useEffect,useState,type FormEvent} from 'react';

export function ResetPasswordForm(){
  const params=useSearchParams();const[token,setToken]=useState('');const[error,setError]=useState('');const[done,setDone]=useState(false);const[pending,setPending]=useState(false);
  useEffect(()=>{const hash=new URLSearchParams(window.location.hash.replace(/^#/,''));setToken(params.get('access_token')||params.get('token')||hash.get('access_token')||'')},[params]);
  async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();const form=new FormData(e.currentTarget);const password=String(form.get('password')||'');if(password!==form.get('confirmPassword')){setError('Passwords do not match.');return}if(!token){setError('This recovery link is missing its security token.');return}setPending(true);const response=await fetch('/api/v1/auth/password/reset',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({accessToken:token,password})});setPending(false);if(!response.ok){setError('This recovery link is invalid or expired.');return}setDone(true)}
  if(done)return <div className="authNotice success">Password updated. <Link href="/login">Sign in</Link>.</div>;
  return <form className="authForm" onSubmit={submit}>{error&&<div className="authNotice danger" role="alert">{error}</div>}<label>New password<input name="password" type="password" autoComplete="new-password" minLength={12} required/></label><label>Confirm password<input name="confirmPassword" type="password" autoComplete="new-password" minLength={12} required/></label><p className="authHint">Use at least 12 characters with uppercase, lowercase and a number.</p><button className="button buttonPrimary" disabled={pending}>{pending?'Updating…':'Update password'}</button></form>
}
