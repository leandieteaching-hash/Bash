#!/usr/bin/env bash
set -euo pipefail
expected=${1:?expected json}; actual=${2:?actual json}
python3 - "$expected" "$actual" <<'PY'
import json,sys
left=json.load(open(sys.argv[1])); right=json.load(open(sys.argv[2]))
if left != right:
 print(json.dumps({'expected':left,'actual':right},indent=2)); raise SystemExit(1)
print('entity counts reconciled')
PY
