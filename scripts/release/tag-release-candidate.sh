#!/usr/bin/env bash
set -euo pipefail

release="${1:-v1.0.0-rc.1}"
report="evidence/${release}/gate-results.json"

[[ -f package-lock.json ]] || { echo 'NO-GO: package-lock.json is missing.' >&2; exit 1; }
[[ -f "$report" ]] || { echo "NO-GO: $report is missing." >&2; exit 1; }

node - "$report" <<'NODE'
const fs = require('fs');
const report = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const failed = report.gates.filter((gate) => gate.mandatory && gate.status !== 'passed');
if (failed.length) {
  console.error(`NO-GO: ${failed.length} mandatory gate(s) have not passed:`);
  for (const gate of failed) console.error(`- ${gate.id}: ${gate.status}`);
  process.exit(1);
}
NODE

git diff --quiet && git diff --cached --quiet || {
  echo 'NO-GO: working tree is not clean.' >&2
  exit 1
}

git tag -s "$release" -m "Studio OS ${release}"
git tag -v "$release"
echo "Created and verified signed tag $release"
