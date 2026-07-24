import {NextResponse} from 'next/server';
import {readSession} from '@/lib/platform/identity';
import {listMatrix,requirePermission} from '@/lib/rbac/service';
export async function GET(request:Request){try{const identity=await readSession(request);if(!identity?.organisationId)return NextResponse.json({error:{code:'UNAUTHENTICATED'}},{status:401});await requirePermission(identity,'identity.roles.read');const matrix=await listMatrix(identity.organisationId);return NextResponse.json({data:matrix,requestId:request.headers.get('x-request-id')??crypto.randomUUID()})}catch(error){return NextResponse.json({error:{code:String(error).includes('FORBIDDEN')?'FORBIDDEN':'RBAC_READ_FAILED'}},{status:String(error).includes('FORBIDDEN')?403:500})}}
