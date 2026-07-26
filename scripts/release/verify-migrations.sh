#!/usr/bin/env bash
set -euo pipefail
mapfile -t files < <(find database/migrations -maxdepth 1 -type f -name '*.sql' | sort)
((${#files[@]} > 0)) || { echo 'no migrations found' >&2; exit 1; }
printf '%s\n' "${files[@]}" | sort -c
for file in "${files[@]}"; do
  grep -Eqi '(create|alter|comment|grant|revoke|insert|update|delete|do[[:space:]]+\$\$)' "$file" || {
    echo "migration has no recognised SQL operation: $file" >&2; exit 1;
  }
done
sha256sum "${files[@]}"
