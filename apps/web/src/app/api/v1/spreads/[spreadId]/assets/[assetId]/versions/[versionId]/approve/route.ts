import { approveAssetVersion } from '@/features/spread-manager/service';
import { approveVersionSchema } from '@/features/spread-manager/schemas';
import { requirePermission,response,errorResponse } from '@/lib/spread-manager-server';
export async function POST(request:Request,{params}:{params:Promise<{spreadId:string;assetId:string;versionId:string}>}){try{const actor=await requirePermission('asset.approve');const {spreadId,assetId,versionId}=await params;return response(await approveAssetVersion(actor,spreadId,assetId,versionId,approveVersionSchema.parse(await request.json())))}catch(e){return errorResponse(e)}}
