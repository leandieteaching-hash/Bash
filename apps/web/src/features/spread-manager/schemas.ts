import { z } from 'zod';

export const reviewRequestSchema = z.object({
  assetId: z.string().uuid(),
  assetVersionId: z.string().uuid(),
  assignedReviewer: z.string().uuid(),
  reviewType: z.string().trim().min(1).max(100),
  instructions: z.string().trim().max(5000).nullable().optional(),
  dueDate: z.string().date().nullable().optional(),
});

export const completeReviewSchema = z.object({
  summary: z.string().trim().max(10000).nullable().optional(),
  decisionRecommendation: z.enum(['Approved', 'Changes Requested', 'No Decision']),
  comments: z.array(z.object({
    comment: z.string().trim().min(1).max(5000),
    severity: z.enum(['Required Change', 'Suggestion', 'Question']),
    pageNumber: z.number().int().positive().nullable().optional(),
    xPosition: z.number().min(0).max(1).nullable().optional(),
    yPosition: z.number().min(0).max(1).nullable().optional(),
  })).default([]),
});

export const resolveCommentSchema = z.object({ resolutionNote: z.string().trim().min(1).max(5000) });
export const approveVersionSchema = z.object({ approvalType: z.string().trim().min(1).max(100), decisionReason: z.string().trim().min(1).max(5000) });
export const revokeApprovalSchema = z.object({ revocationReason: z.string().trim().min(1).max(5000) });
export const lockSchema = z.object({ reason: z.string().trim().min(1).max(5000) });

export const taskPatchSchema = z.object({
  title: z.string().trim().min(1).max(250).optional(),
  description: z.string().trim().max(5000).nullable().optional(),
  department: z.string().trim().max(100).nullable().optional(),
  status: z.enum(['Not Started', 'In Progress', 'Blocked', 'Completed', 'Cancelled']).optional(),
  priority: z.enum(['Critical', 'High', 'Medium', 'Low']).optional(),
  assignedTo: z.string().uuid().nullable().optional(),
  dueDate: z.string().date().nullable().optional(),
  blockedReason: z.string().trim().max(5000).nullable().optional(),
});

export const approveDecisionSchema = z.object({ note: z.string().trim().max(5000).nullable().optional() });
export const supersedeDecisionSchema = z.object({
  decisionCode: z.string().trim().min(1).max(100),
  title: z.string().trim().min(1).max(250),
  context: z.string().trim().max(10000).nullable().optional(),
  optionsConsidered: z.array(z.string().trim().min(1)).default([]),
  finalDecision: z.string().trim().min(1).max(10000),
  reason: z.string().trim().min(1).max(10000),
});
