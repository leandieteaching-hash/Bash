# Authorization model

Authorization is permission based. A user receives roles within an organisation; roles grant permissions and may inherit from a parent role. `public.has_permission` evaluates the effective role graph for the request user and organisation.

Administrative mutations require both tenant membership and the relevant management permission. Audit events must record role assignment and permission changes.
