import {NextResponse} from 'next/server';
import {readSession} from '@/lib/platform/identity';
import {listRevisions} from '@/features/spread-editor/editor-service';
export async function GET(request:Request,{params}:{params:Promise<{spreadId:string}>}){const requestId=request.headers.get('x-request-id')??crypto.randomUUID();try{const identity=await readSession(request);if(!identity?.organisationId)return NextResponse.json({error:{code:'UNAUTHENTICATED'},requestId},{status:401});const {spreadId}=await params;return NextResponse.json({data:await listRevisions(identity,spreadId),requestId})}catch(error){return NextResponse.json({error:{code:String(error).includes('FORBIDDEN')?'FORBIDDEN':'REVISION_LIST_FAILED'},requestId},{status:String(error).includes('FORBIDDEN')?403:500})}}
