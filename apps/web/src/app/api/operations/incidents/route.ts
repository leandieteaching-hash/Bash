import {NextResponse} from 'next/server';import {z} from 'zod';
const schema=z.object({title:z.string().min(3),severity:z.enum(['info','warning','critical']),source:z.string().min(2),details:z.record(z.unknown()).optional()});
export async function POST(request:Request){const parsed=schema.safeParse(await request.json());if(!parsed.success)return NextResponse.json({error:'Invalid incident',issues:parsed.error.flatten()},{status:400});return NextResponse.json({incident:{id:crypto.randomUUID(),status:'open',createdAt:new Date().toISOString(),...parsed.data}},{status:201})}
