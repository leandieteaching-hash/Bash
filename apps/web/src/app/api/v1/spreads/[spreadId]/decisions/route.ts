import { createDecision } from '@/features/spread-manager/service';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function POST(request: Request, { params }: { params: Promise<{ spreadId: string }> }) {
  try { const actor = await requirePermission('decision.create'); const { spreadId } = await params;
    return response(await createDecision(actor, spreadId, await request.json()), 201); }
  catch (error) { return errorResponse(error); }
}
