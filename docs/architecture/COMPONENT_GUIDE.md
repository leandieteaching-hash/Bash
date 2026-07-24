# Component Guide

- `AppShell`: global responsive chrome.
- `BookWorkspaceHeader`: persistent book context and workspace navigation.
- `PageHeader` and `Breadcrumbs`: consistent page framing.
- `StatusBadge`: shared semantic state display.
- CSS design tokens: `src/styles/tokens.css`.

Feature modules should compose these primitives instead of introducing parallel layout systems.
