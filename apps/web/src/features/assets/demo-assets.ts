import type {Asset,AssetCollection} from './types';
const now='2026-07-22T10:00:00.000Z';
const make=(id:string,title:string,type:Asset['type'],status:Asset['reviewStatus'],version:number,tags:string[],owner:string,usage:string[]):Asset=>({
 id,bookId:'meet-mia',title,type,tags,owner,description:`Production ${type} asset for Meet Mia.`,createdAt:'2026-06-01T08:00:00.000Z',updatedAt:now,reviewStatus:status,lifecycleStatus:'active',collectionIds:type==='character'?['characters']:type==='environment'?['world']:['spread-art'],
 currentVersion:{id:`${id}-v${version}`,version,filename:`${id}-v${version}.svg`,mimeType:'image/svg+xml',sizeBytes:180000+version*32000,width:1600,height:1200,storagePath:`books/meet-mia/assets/${id}/v${version}/${id}.svg`,createdAt:now,createdBy:owner,reviewStatus:status,isCurrent:true,thumbnailUrl:''},
 versions:Array.from({length:version},(_,i)=>({id:`${id}-v${i+1}`,version:i+1,filename:`${id}-v${i+1}.svg`,mimeType:'image/svg+xml',sizeBytes:150000+(i+1)*32000,width:1600,height:1200,storagePath:`books/meet-mia/assets/${id}/v${i+1}/${id}.svg`,createdAt:`2026-07-${String(10+i).padStart(2,'0')}T10:00:00.000Z`,createdBy:owner,reviewStatus:i+1===version?status:'draft',isCurrent:i+1===version})),
 usage:usage.map((label,i)=>({id:`${id}-u${i}`,contextType:'spread',contextId:`spread-${i+1}`,label,usageRole:'primary illustration',updatedAt:now})),relationships:[]
});
export const demoAssets:Asset[]=[
 make('mia-window','Mia at the Window','illustration','in_review',3,['mia','interior','morning'],'Lerato Dlamini',['Spread 04','Spread 05']),
 make('mia-character','Mia Character Master','character','approved',5,['mia','character','master'],'Lerato Dlamini',['Spread 01','Spread 04','Spread 08']),
 make('yellow-coat','Yellow Coat Turnaround','character','changes_requested',2,['mia','wardrobe','yellow-coat'],'Ayesha Khan',['Character Bible']),
 make('bedroom-wide','Mia Bedroom Wide','environment','approved',4,['bedroom','interior','environment'],'Jonas Meyer',['Spread 03','Spread 04']),
 make('garden-dawn','Garden at Dawn','environment','draft',1,['garden','exterior','morning'],'Jonas Meyer',['Spread 12']),
 make('spread-08-layout','Spread 08 Layout','layout','in_review',2,['layout','spread-08'],'Anna Smit',['Spread 08']),
 make('cover-concept-a','Cover Concept A','cover','draft',2,['cover','concept'],'Lerato Dlamini',['Cover']),
 make('colour-script','Book Colour Script','reference','approved',3,['palette','reference'],'Anna Smit',['All spreads'])
];
export const demoCollections:AssetCollection[]=[
 {id:'characters',name:'Character Masters',description:'Approved and working character references.',assetCount:2},
 {id:'world',name:'World & Environments',description:'Reusable locations and environmental references.',assetCount:2},
 {id:'spread-art',name:'Spread Artwork',description:'Illustrations and layouts used in spreads.',assetCount:3},
 {id:'publishing',name:'Publishing Candidates',description:'Assets considered for cover and final exports.',assetCount:1}
];
