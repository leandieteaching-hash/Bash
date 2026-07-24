import {VisualSpreadEditor} from '@/features/spread-editor/VisualSpreadEditor';
export default async function Page({params}:{params:Promise<{spreadId:string}>}){const {spreadId}=await params;return <main><h1>Visual spread editor</h1><p>Place text, shapes, and assets on the spread canvas. Changes autosave with optimistic concurrency.</p><VisualSpreadEditor spreadId={spreadId}/></main>}
