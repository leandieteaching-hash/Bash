export type AnnotationStatus='open'|'in_discussion'|'resolved'|'verified'|'closed';
export type ReviewComment={id:string;annotationId:string;parentCommentId:string|null;body:string;mentions:string[];createdBy:string|null;createdAt:string};
export type SpreadAnnotation={id:string;spreadId:string;reviewCycleId:string|null;elementId:string|null;annotationType:'pin'|'region'|'highlight'|'drawing';x:number|null;y:number|null;width:number|null;height:number|null;status:AnnotationStatus;createdBy:string|null;createdAt:string;comments:ReviewComment[]};
export type ReviewCycle={id:string;spreadId:string;title:string;roundNumber:number;status:'open'|'in_review'|'completed'|'cancelled';dueAt:string|null;createdAt:string};
