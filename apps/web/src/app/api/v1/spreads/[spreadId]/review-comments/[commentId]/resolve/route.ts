import { resolveReviewComment } from '@/features/spread-manager/service';
import { resolveCommentSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;commentId:string}>}){try{const actor=await requirePermission('review.resolve_comment');const {spreadId,commentId}=await params;const body=resolveCommentSchema.parse(await request.json());return response(await resolveReviewComment(actor,spreadId,commentId,body.resolutionNote))}catch(e){return errorResponse(e)}}
