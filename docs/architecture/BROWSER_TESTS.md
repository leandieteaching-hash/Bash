# Browser workflow tests

This package adds Playwright coverage for the complete Spread Manager workflow across the browser, API routes, transactional RPCs, and PostgreSQL state.

## Covered journey

1. Upload Version 2 and verify Version 1 remains immutable.
2. Request a review for Version 2.
3. Complete the review with a required-change comment.
4. Resolve the required-change comment.
5. Approve Version 2.
6. Revoke that approval and switch the current version to Version 1.
7. Lock the spread.
8. Unlock the spread.
9. Supersede an approved decision while preserving the old decision.

The suite runs serially because each step intentionally builds on the committed state from the previous step. Every UI assertion is paired with a service-role database assertion.

## Required fixture

Use a dedicated test project or test book. Before execution, seed:

- one spread;
- one asset with exactly Version 1;
- one active reviewer;
- one approved, non-superseded decision;
- one test user with all permissions used by the journey.

Set the IDs in `tests/e2e/.env`. Never run this mutation suite against production data.

## Run

```bash
cp tests/e2e/.env.example .env.e2e
# fill in the values
npx playwright install chromium
npx playwright test
```

Or run database and browser coverage together:

```bash
npm run test:workflow
```

## Authentication

`global-setup.ts` signs in through Supabase Auth and writes a Playwright storage state. The service-role key is used only by Node test assertions and is never injected into the browser.

## Failure evidence

On failure Playwright retains:

- trace;
- screenshot;
- video;
- HTML report.
