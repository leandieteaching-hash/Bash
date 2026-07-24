import {adminDb} from '@/lib/spread-manager-server';
import type {SessionIdentity} from '@studio-os/auth';
import {requirePermission} from '@/lib/rbac/service';

export async function listBooks(identity:SessionIdentity){
  await requirePermission(identity,'books.read');
  const {data,error}=await adminDb().from('books').select('id,code,title,subtitle,status,lifecycle_stage,default_language,updated_at').eq('organisation_id',identity.organisationId).is('archived_at',null).order('updated_at',{ascending:false});
  if(error)throw error;return data??[];
}
export async function getBook(identity:SessionIdentity,bookId:string){
  await requirePermission(identity,'books.read');
  const {data,error}=await adminDb().from('books').select('*,book_editions(*),book_sections(*),book_contributors(*),book_milestones(*)').eq('organisation_id',identity.organisationId).eq('id',bookId).single();
  if(error)throw error;return data;
}
export async function createBook(identity:SessionIdentity,input:{code:string;title:string;subtitle?:string;description?:string;language:string}){
  await requirePermission(identity,'books.create');
  const {data,error}=await adminDb().rpc('create_book_with_first_edition',{p_organisation_id:identity.organisationId,p_user_id:identity.userId,p_code:input.code,p_title:input.title,p_subtitle:input.subtitle??null,p_description:input.description??null,p_language:input.language});
  if(error)throw error;return data as string;
}
