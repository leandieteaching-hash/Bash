export type ElementKind='text'|'image'|'shape';
export type SpreadElement={id:string;kind:ElementKind;x:number;y:number;width:number;height:number;rotation:number;locked?:boolean;assetId?:string;assetVersionId?:string;src?:string;text?:string;fill?:string;zIndex:number};
export type SpreadDocument={id:string;spreadId:string;widthPt:number;heightPt:number;bleedPt:number;gridSizePt:number;snapToGrid:boolean;version:number;elements:SpreadElement[]};
export type EditorTool='select'|'text'|'rectangle'|'image';
