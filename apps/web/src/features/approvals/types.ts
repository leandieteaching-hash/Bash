export type ApprovalDecision='approved'|'rejected'|'abstained';
export type ApprovalAssignment={id:string;approverId:string;status:'pending'|ApprovalDecision;assignedAt:string;decidedAt:string|null};
export type ApprovalStage={id:string;stageNumber:number;name:string;requiredApprovals:number;status:'pending'|'active'|'approved'|'rejected'|'skipped';assignments:ApprovalAssignment[]};
export type ApprovalWorkflow={id:string;spreadId:string;name:string;status:'draft'|'active'|'completed'|'cancelled';currentStage:number;version:number;stages:ApprovalStage[];createdAt:string};
