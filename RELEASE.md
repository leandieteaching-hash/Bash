# Release policy

Studio OS releases are created only by the tag-triggered GitHub Actions workflow.

A baseline tag may be created only after all of the following pass from a clean checkout:

```bash
npm ci
npm run typecheck
npm run build
npm run test:release
```

Use `scripts/tag-verified-baseline.sh` to enforce these gates locally. The release workflow produces the source ZIP and container image; developers do not publish hand-built release artifacts.
