export type Permission = `${string}.${string}`;
export type AuthorizationContext = { permissions: ReadonlySet<string> };

export function can(context: AuthorizationContext, permission: Permission): boolean {
  return context.permissions.has(permission) || context.permissions.has('platform.admin');
}

export function authorize(context: AuthorizationContext, permission: Permission): void {
  if (!can(context, permission)) throw new Error(`FORBIDDEN:${permission}`);
}
