import { revokeApproval } from '@/features/spread-manager/service';
import { revokeApprovalSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;approvalId:string}>}){try{const actor=await requirePermission('asset.approve');const {spreadId,approvalId}=await params;const body=revokeApprovalSchema.parse(await request.json());return response(await revokeApproval(actor,spreadId,approvalId,body.revocationReason))}catch(e){return errorResponse(e)}}
