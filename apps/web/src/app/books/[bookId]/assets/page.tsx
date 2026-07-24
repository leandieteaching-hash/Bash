import {PageHeader} from '@/components/layout/Page';
import {AssetLibrary} from '@/features/assets/AssetLibrary';
export default async function AssetsPage({params}:{params:Promise<{bookId:string}>}){const {bookId}=await params;return <><PageHeader title="Asset Library" description="Search, upload, version, relate and govern every production asset."/><AssetLibrary bookId={bookId}/></>}
