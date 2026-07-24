# Contributing to Studio OS

## Development workflow

1. Branch from `main` using `feat/`, `fix/`, `docs/`, `refactor/`, or `chore/`.
2. Keep each pull request focused on one independently reviewable change.
3. Use Conventional Commits.
4. Update tests and documentation with behavior changes.
5. Run `npm run verify` before requesting review.

## Local setup

```bash
cp .env.example .env
npm ci
npm run dev:services
npm run dev
```

PostgreSQL runs on port 5432. Mailpit SMTP runs on 1025 and its inbox is at port 8025.

## Definition of done

A change requires architecture, database, backend, API, frontend, authorization, audit, tests, documentation, and CI coverage where those concerns apply.
