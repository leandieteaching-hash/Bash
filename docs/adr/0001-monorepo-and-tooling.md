# ADR 0001: npm workspace monorepo and shared tooling

- Status: Accepted
- Date: 2026-07-24

## Context

Studio OS will contain multiple applications, workers, SDKs, and shared platform packages. They must evolve under one review and release process.

## Decision

Use an npm workspace monorepo, Node.js 20, TypeScript strict mode, shared configuration packages, Prettier, ESLint, Husky, lint-staged, Conventional Commits, and Turbo task metadata. CI remains the source of truth.

## Consequences

Changes can be coordinated atomically and tooling is consistent. Repository-wide CI can become slower as the product grows, so task caching and affected-package execution will be introduced when measurements justify it.
