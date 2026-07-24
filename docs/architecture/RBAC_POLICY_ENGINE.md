# RBAC policy engine

## Evaluation sequence

1. Authenticate the request and load the persisted active organisation.
2. Verify active organisation membership.
3. Load direct role assignments for the user and organisation.
4. Walk parent roles recursively.
5. Collect effective permission grants.
6. Apply explicit denial rules in the application policy context when present.
7. Return an allow or deny decision with a reason suitable for diagnostics.

## Administration

The Roles & Permissions screen reads the complete role-permission matrix. Updates replace one role's grants atomically through `replace_role_permissions`. Role creation and member role assignment have dedicated versioned endpoints. Every mutation writes an audit event containing the actor, tenant, resource and resulting grant identifiers.

## Security properties

- Organisation IDs are taken from the authenticated session, never request payloads.
- Database authorization requires active membership.
- System roles are readable across tenants but tenant roles are isolated.
- RLS protects roles, grants and assignments.
- Service-role access is used only behind authenticated APIs that call the same policy checks.
