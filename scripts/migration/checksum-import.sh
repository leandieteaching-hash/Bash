#!/usr/bin/env bash
set -euo pipefail
root=${1:?usage: checksum-import.sh <directory>}
find "$root" -type f -print0 | sort -z | xargs -0 sha256sum
