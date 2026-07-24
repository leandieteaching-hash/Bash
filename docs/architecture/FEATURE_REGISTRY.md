# Feature Registry

Register features in `src/features/registry.ts` with an id, label, scope, route, permission and description. Lazy modules can also provide `load()`.

Book-scoped features appear beneath `/books/[bookId]`. Global features use absolute routes. Spread features mount beneath a spread route. Permission filtering belongs in the navigation adapter and uses the shared `AppProviders` permission contract.
