# Studio OS Application Shell Architecture

The shell uses nested Next.js App Router layouts:

1. Root layout: global providers, design tokens and the application chrome.
2. Book layout: persistent Book Workspace header and section navigation.
3. Spread route: Spread Board to Spread Manager navigation.

Feature modules register metadata in `src/features/registry.ts`. The shell does not perform workflow mutations. Existing feature services continue to use API routes and transactional PostgreSQL RPC functions.

## Integration boundaries

- **RPCs:** existing API routes remain the only browser mutation boundary.
- **Realtime:** feature hooks subscribe independently; the shell displays global connection state.
- **Notifications:** `/notifications` is a registered global module and header destination.
- **Reports:** global and book-scoped report routes are present.
- **Spread Manager:** mounted directly at the nested manager route.
