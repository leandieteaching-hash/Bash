import {redirect} from 'next/navigation';export default async function Book({params}:{params:Promise<{bookId:string}>}){const{bookId}=await params;redirect(`/books/${bookId}/overview`)}
