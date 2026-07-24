'use client';
import {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';

type Organisation = {id:string;name:string;isDefault:boolean};
export function OrganisationSwitcher() {
  const router=useRouter();
  const [items,setItems]=useState<Organisation[]>([]);
  const [active,setActive]=useState('');
  useEffect(()=>{void fetch('/api/v1/me').then(r=>r.ok?r.json():null).then(body=>{if(!body)return;setItems(body.data.organisations);setActive(body.data.activeOrganisationId??'')})},[]);
  async function change(organisationId:string){setActive(organisationId);const response=await fetch('/api/v1/organisations/switch',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({organisationId})});if(!response.ok){router.push('/session-expired');return}router.refresh()}
  if(items.length<2)return null;
  return <label className="organisationSwitcher"><span className="srOnly">Active organisation</span><select value={active} onChange={event=>void change(event.target.value)}>{items.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label>;
}
