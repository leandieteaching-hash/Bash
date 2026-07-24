import { setSpreadLock } from '@/features/spread-manager/service';
import { lockSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string}>}){try{const actor=await requirePermission('spread.lock');const {spreadId}=await params;const body=lockSchema.parse(await request.json());return response(await setSpreadLock(actor,spreadId,false,body.reason))}catch(e){return errorResponse(e)}}
