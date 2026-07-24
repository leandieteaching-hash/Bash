import { createReviewRequest } from '@/features/spread-manager/service';
import { reviewRequestSchema } from '@/features/spread-manager/schemas';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string}>}){try{const actor=await requirePermission('review.request');const {spreadId}=await params;return response(await createReviewRequest(actor,spreadId,reviewRequestSchema.parse(await request.json())),201)}catch(e){return errorResponse(e)}}
