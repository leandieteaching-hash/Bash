import {NextResponse} from 'next/server';
import {z} from 'zod';
import {readSession} from '@/lib/platform/identity';
import {replaceRolePermissions} from '@/lib/rbac/service';
const schema=z.object({permissions:z.array(z.string().min(3)).max(250)});
export async function PUT(request:Request,{params}:{params:Promise<{roleId:string}>}){const requestId=request.headers.get('x-request-id')??crypto.randomUUID();try{const identity=await readSession(request);if(!identity?.organisationId)return NextResponse.json({error:{code:'UNAUTHENTICATED'},requestId},{status:401});const body=schema.parse(await request.json());const {roleId}=await params;await replaceRolePermissions(identity,roleId,body.permissions,requestId);return NextResponse.json({data:{roleId,permissions:body.permissions},requestId})}catch(error){const forbidden=String(error).includes('FORBIDDEN');return NextResponse.json({error:{code:forbidden?'FORBIDDEN':'RBAC_UPDATE_FAILED'},requestId},{status:forbidden?403:400})}}
