# PR-021 Release Candidate Validation Report

## Scope

This pass attempted to produce Studio OS `v1.0.0-rc.1` from the reconciled `main` branch.

## Environment

- Node.js: v22.16.0
- npm: 10.9.2
- Required package manager declared by repository: npm 10.8.2
- Configured registry: internal npm proxy
- Registry result: HTTP 503
- npm cache: zero cached package objects

The npm version mismatch must also be resolved or explicitly approved before final evidence is signed. The clean CI runner should use the repository-declared package manager version through Corepack or an equivalent pinned toolchain.

## Executed successfully

```text
npm run test:release
npm run security:static
bash syntax validation for repository shell scripts
git diff --check
```

The structural suite covered approvals, reviews, editor history, spread editing, books, RBAC, tenancy, authentication, identity, platform foundation, application shell, operations, assets and reports.

## Not executable in this environment

The following were not marked successful:

```text
npm install / package-lock generation
npm ci
npm run format:check
npm run lint
npm run typecheck
npm audit
npm run build
npm run test:integration
Playwright E2E
staging deployment and rollback
backup and restore drill
k6 performance execution
OWASP ZAP DAST
independent penetration test
signed release tag
```

## Release-blocking defects

No application defect can be inferred merely from a missing toolchain. However, the absence of a reproducible dependency graph and compiled build is itself a release blocker. Any defects discovered when the blocked gates are executed must be fixed on this branch, and the entire gate set rerun from a clean environment.
