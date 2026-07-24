import { updateTask } from '@/features/spread-manager/service';
import { requirePermission, response, errorResponse } from '@/lib/spread-manager-server';
export async function PATCH(request: Request, { params }: { params: Promise<{ spreadId: string; taskId: string }> }) {
  try { const actor = await requirePermission('task.edit'); const { spreadId, taskId } = await params;
    return response(await updateTask(actor, spreadId, taskId, await request.json())); }
  catch (error) { return errorResponse(error); }
}
