# ADR 0005: Tenant-scoped RBAC policy engine

## Status
Accepted

## Decision
Studio OS evaluates authorization from tenant-scoped role assignments and granular permissions. Roles may inherit from one parent role. Effective permissions are calculated in PostgreSQL and exposed through a shared TypeScript decision API. All administration mutations require explicit management permissions and write immutable audit events.

## Consequences
- Application routes and database functions use the same permission vocabulary.
- Tenant membership is required before any tenant permission can be effective.
- Platform administration is represented by the explicit `platform.admin` permission.
- Permission replacement is atomic and versioned.
- Role cycles must be prevented by administration validation and migration tests.
