import { supersedeDecision } from '@/features/spread-manager/service';
import { supersedeDecisionSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;decisionId:string}>}){try{const actor=await requirePermission('decision.approve');const {spreadId,decisionId}=await params;return response(await supersedeDecision(actor,spreadId,decisionId,supersedeDecisionSchema.parse(await request.json())),201)}catch(e){return errorResponse(e)}}
