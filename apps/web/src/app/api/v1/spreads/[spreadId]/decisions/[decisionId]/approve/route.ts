import { approveDecision } from '@/features/spread-manager/service';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function POST(_request: Request, { params }: { params: Promise<{ spreadId: string; decisionId: string }> }) {
  try { const actor = await requirePermission('decision.approve'); const { spreadId, decisionId } = await params;
    return response(await approveDecision(actor, spreadId, decisionId)); }
  catch (error) { return errorResponse(error); }
}
