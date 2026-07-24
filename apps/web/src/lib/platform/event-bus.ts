export type StudioEvent<T=unknown>={id:string;type:string;tenantId:string;occurredAt:string;actorId:string;data:T;version:1};
const subscribers=new Map<string,Set<(event:StudioEvent)=>void>>();
export function createEvent<T>(input:Omit<StudioEvent<T>,'id'|'occurredAt'|'version'>):StudioEvent<T>{return {...input,id:crypto.randomUUID(),occurredAt:new Date().toISOString(),version:1}}
export function publishEvent(event:StudioEvent){for(const handler of subscribers.get(event.type)??[])handler(event);for(const handler of subscribers.get('*')??[])handler(event)}
export function subscribe(type:string,handler:(event:StudioEvent)=>void){const handlers=subscribers.get(type)??new Set();handlers.add(handler);subscribers.set(type,handlers);return()=>handlers.delete(handler)}
