import { addCharacter } from '@/features/spread-manager/service';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function POST(request: Request, { params }: { params: Promise<{ spreadId: string }> }) {
  try { const actor = await requirePermission('spread.edit'); const { spreadId } = await params;
    const body = await request.json(); return response(await addCharacter(actor, spreadId, body), 201); }
  catch (error) { return errorResponse(error); }
}
