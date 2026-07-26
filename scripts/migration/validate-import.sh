#!/usr/bin/env bash
set -euo pipefail
input=${1:?usage: validate-import.sh <manifest.json>}
python3 - "$input" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); data=json.loads(p.read_text())
required={'source_system','organization','idempotency_key','files'}
missing=sorted(required-set(data))
if missing: raise SystemExit('missing fields: '+', '.join(missing))
if not isinstance(data['files'],list) or not data['files']: raise SystemExit('files must be a non-empty list')
for item in data['files']:
    if not {'path','sha256','entity'}.issubset(item): raise SystemExit('each file requires path, sha256 and entity')
print('manifest valid')
PY
