import type {AssetFilters,AssetType,LifecycleStatus} from './types';
export type SignedUpload={uploadUrl:string;storagePath:string;token?:string};
async function request<T>(url:string,init?:RequestInit):Promise<T>{const response=await fetch(url,{...init,headers:{'content-type':'application/json',...(init?.headers||{})}});if(!response.ok){const body=await response.json().catch(()=>({}));throw new Error(body.error||`Request failed (${response.status})`)}return response.json() as Promise<T>}
export const assetService={
 search:(bookId:string,filters:AssetFilters)=>request('/api/assets/search',{method:'POST',body:JSON.stringify({bookId,filters})}),
 createUpload:(input:{bookId:string;assetId?:string;filename:string;contentType:string;sizeBytes:number;assetType:AssetType})=>request<SignedUpload>('/api/assets/upload-url',{method:'POST',body:JSON.stringify(input)}),
 finalizeUpload:(input:{bookId:string;assetId?:string;title:string;assetType:AssetType;storagePath:string;filename:string;contentType:string;sizeBytes:number;tags:string[]})=>request('/api/assets/finalize',{method:'POST',body:JSON.stringify(input)}),
 bulkUpdate:(input:{assetIds:string[];operation:'add_tags'|'remove_tags'|'add_collection'|'archive'|'restore'|'lifecycle';tags?:string[];collectionId?:string;lifecycle?:LifecycleStatus})=>request('/api/assets/bulk',{method:'POST',body:JSON.stringify(input)})
};
