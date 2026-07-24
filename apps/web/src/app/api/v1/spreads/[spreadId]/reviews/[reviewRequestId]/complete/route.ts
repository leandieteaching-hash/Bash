import { completeReview } from '@/features/spread-manager/service';
import { completeReviewSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;reviewRequestId:string}>}){try{const actor=await requirePermission('review.complete');const {spreadId,reviewRequestId}=await params;return response(await completeReview(actor,spreadId,reviewRequestId,completeReviewSchema.parse(await request.json())))}catch(e){return errorResponse(e)}}
