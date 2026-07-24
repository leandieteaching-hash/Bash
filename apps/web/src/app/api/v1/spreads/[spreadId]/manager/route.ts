import { getManager } from '@/features/spread-manager/service';
import { errorResponse, requirePermission } from '@/lib/spread-manager-server';

export async function GET(_: Request, { params }: { params: Promise<{ spreadId: string }> }) {
  try {
    const actor = await requirePermission('spread.view');
    const { spreadId } = await params;
    return Response.json({ data: await getManager(spreadId, actor) });
  } catch (error) { return errorResponse(error); }
}
