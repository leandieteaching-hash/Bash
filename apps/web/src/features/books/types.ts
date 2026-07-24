export type BookStatus='draft'|'active'|'on_hold'|'completed'|'archived';
export type BookStage='planning'|'writing'|'editing'|'design'|'review'|'production'|'published';
export type BookSummary={id:string;code:string;title:string;subtitle:string|null;status:BookStatus;lifecycle_stage:BookStage;default_language:string;updated_at:string};
export type BookDetail=BookSummary&{description:string|null;target_market:string|null;metadata:Record<string,unknown>;book_editions?:unknown[];book_sections?:unknown[];book_contributors?:unknown[];book_milestones?:unknown[]};
