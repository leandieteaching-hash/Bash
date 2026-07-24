'use client';
import {useRouter} from 'next/navigation';
export function LogoutButton(){const router=useRouter();async function logout(){await fetch('/api/v1/auth/logout',{method:'POST'});router.replace('/login');router.refresh()}return <button className="iconButton" aria-label="Sign out" title="Sign out" onClick={logout}>LJ</button>}
