import {NextResponse} from 'next/server';
import {z} from 'zod';
import {readSession} from '@/lib/platform/identity';
import {restoreRevision} from '@/features/spread-editor/editor-service';
const schema=z.object({expectedVersion:z.number().int().positive()});
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;revisionId:string}>}){const requestId=request.headers.get('x-request-id')??crypto.randomUUID();try{const identity=await readSession(request);if(!identity?.organisationId)return NextResponse.json({error:{code:'UNAUTHENTICATED'},requestId},{status:401});const {spreadId,revisionId}=await params;const body=schema.parse(await request.json());return NextResponse.json({data:await restoreRevision(identity,spreadId,revisionId,body.expectedVersion,requestId),requestId})}catch(error){const message=String(error);return NextResponse.json({error:{code:message.includes('VERSION_CONFLICT')?'VERSION_CONFLICT':message.includes('FORBIDDEN')?'FORBIDDEN':'REVISION_RESTORE_FAILED'},requestId},{status:message.includes('VERSION_CONFLICT')?409:message.includes('FORBIDDEN')?403:400})}}
