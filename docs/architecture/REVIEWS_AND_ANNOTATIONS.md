# Reviews and annotations

PR-013 adds collaborative review to visual spreads.

- `review_cycles` defines review rounds and deadlines.
- `review_assignments` records reviewers and completion.
- `spread_annotations` anchors discussion to coordinates, regions or elements.
- `review_comments` stores threaded discussion and mentions.
- `review_comment_history` preserves edited content.

The editor reads reviews from `/api/v1/spreads/:spreadId/reviews`. Annotation, comment and status mutations use dedicated versioned endpoints and publish audit and outbox events. Resolved annotations remain available for filtering and verification rather than being deleted.

Coordinates use the same print-point system as the spread document. This keeps annotation anchors stable across zoom levels. Element-linked annotations retain `element_id` so a later editor can follow moved elements while preserving the original coordinate fallback.
