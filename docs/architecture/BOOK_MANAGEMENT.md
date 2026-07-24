# Book Management

## Domain model

`books` stores the publication identity and lifecycle. `book_editions` captures release-specific identifiers, format and trim dimensions. `book_sections` provides an ordered hierarchy for parts, chapters, units and supporting matter. `book_contributors` stores credits independently of platform membership, and `book_milestones` tracks major delivery dates.

## Security

Every record carries `organisation_id`. PostgreSQL RLS compares this value with the transaction-scoped tenant context and evaluates `books.*` permissions through the shared RBAC engine. API handlers derive identity from the authenticated platform session; tenant headers are not accepted as authority.

## Consistency

Creation uses `create_book_with_first_edition`, ensuring a book never exists without an edition. Mutable books use optimistic version checks. Sections have unique slugs per book and deterministic sequence positions per parent.

## Integration

Book mutations write audit events and outbox events. Asset Library objects are linked by stable IDs. Spread Manager continues to operate beneath the book aggregate. Future editions, translation, rights, print and digital distribution services should reference `book_id` and, where release-specific, `book_edition_id`.
