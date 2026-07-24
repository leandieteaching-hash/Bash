import type {SpreadDocument,SpreadElement} from './types';
export function snap(value:number,grid:number,enabled:boolean){return enabled?Math.round(value/grid)*grid:value}
export function constrain(element:SpreadElement,doc:Pick<SpreadDocument,'widthPt'|'heightPt'>):SpreadElement{return {...element,x:Math.max(0,Math.min(element.x,doc.widthPt-element.width)),y:Math.max(0,Math.min(element.y,doc.heightPt-element.height))}}
export function moveElement(doc:SpreadDocument,id:string,x:number,y:number):SpreadDocument{return {...doc,elements:doc.elements.map(el=>el.id===id?constrain({...el,x:snap(x,doc.gridSizePt,doc.snapToGrid),y:snap(y,doc.gridSizePt,doc.snapToGrid)},doc):el)}}
export function addElement(doc:SpreadDocument,element:SpreadElement):SpreadDocument{return {...doc,elements:[...doc.elements,constrain(element,doc)]}}
export function removeElement(doc:SpreadDocument,id:string):SpreadDocument{return {...doc,elements:doc.elements.filter(el=>el.id!==id)}}
export function placeAsset(doc:SpreadDocument,input:{assetId:string;assetVersionId?:string;src:string;width?:number;height?:number}):SpreadDocument{return addElement(doc,{id:crypto.randomUUID(),kind:'image',x:doc.gridSizePt*2,y:doc.gridSizePt*2,width:input.width??240,height:input.height??160,rotation:0,zIndex:doc.elements.length,assetId:input.assetId,assetVersionId:input.assetVersionId,src:input.src})}
