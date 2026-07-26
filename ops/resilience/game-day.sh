#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
  database-failover|region-loss|queue-backlog|object-storage-outage) echo "Game-day scenario registered: $1" ;;
  *) echo 'usage: game-day.sh {database-failover|region-loss|queue-backlog|object-storage-outage}' >&2; exit 2 ;;
esac
