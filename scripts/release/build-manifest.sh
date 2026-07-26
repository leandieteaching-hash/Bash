#!/usr/bin/env bash
set -euo pipefail
version=${1:-v1.0.0}
out=${2:-evidence/$version/release-manifest.json}
mkdir -p "$(dirname "$out")"
commit=$(git rev-parse HEAD)
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 - "$version" "$commit" "$created" "$out" <<'PY'
import json,sys
version,commit,created,out=sys.argv[1:]
json.dump({"version":version,"commit":commit,"created_at":created,"immutable_image_required":True,"release_status":"candidate"},open(out,'w'),indent=2)
open(out,'a').write('\n')
PY
sha256sum "$out" > "$out.sha256"
