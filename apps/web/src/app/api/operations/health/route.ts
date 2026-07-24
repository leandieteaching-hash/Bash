import {NextResponse} from 'next/server';
export async function GET(){const started=Date.now();return NextResponse.json({status:'healthy',service:'studio-os',timestamp:new Date().toISOString(),checks:{application:'ok',configuration:process.env.NEXT_PUBLIC_SUPABASE_URL?'ok':'degraded'},latencyMs:Date.now()-started},{headers:{'Cache-Control':'no-store'}})}
