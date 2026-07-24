import { removeCharacter } from '@/features/spread-manager/service';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function DELETE(_request: Request, { params }: { params: Promise<{ spreadId: string; appearanceId: string }> }) {
  try { const actor = await requirePermission('spread.edit'); const { spreadId, appearanceId } = await params;
    await removeCharacter(actor, spreadId, appearanceId); return response({ success: true }); }
  catch (error) { return errorResponse(error); }
}
