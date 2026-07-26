#!/usr/bin/env bash
set -euo pipefail
backup_epoch=${1:?backup epoch}; recovery_start=${2:?recovery start epoch}; recovery_end=${3:?recovery end epoch}
rpo_limit=${RPO_SECONDS:-900}; rto_limit=${RTO_SECONDS:-3600}
now=$(date +%s); rpo=$((now-backup_epoch)); rto=$((recovery_end-recovery_start))
printf 'RPO=%ss (limit %ss)\nRTO=%ss (limit %ss)\n' "$rpo" "$rpo_limit" "$rto" "$rto_limit"
(( rpo <= rpo_limit && rto <= rto_limit ))
