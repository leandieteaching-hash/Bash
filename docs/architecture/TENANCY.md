# Multi-tenancy

Studio OS uses shared-schema multi-tenancy with PostgreSQL Row Level Security. Tenant-owned tables include `organisation_id`, and policies compare it with `public.current_organisation_id()`.

The active organisation must be one of the user's active memberships. Organisation switching changes session context; it does not grant membership or permissions. Background jobs must carry the originating organisation ID explicitly.
