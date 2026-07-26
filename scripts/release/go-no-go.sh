#!/usr/bin/env bash
set -euo pipefail
results=${1:?usage: go-no-go.sh <gate-results.json>}
python3 - "$results" <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
mandatory=data.get('mandatory',{})
failed=[name for name,state in mandatory.items() if state != 'passed']
if failed:
 print('NO-GO: '+', '.join(failed)); raise SystemExit(1)
print('GO: all mandatory release gates passed')
PY
