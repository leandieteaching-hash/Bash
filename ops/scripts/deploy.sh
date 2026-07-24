#!/usr/bin/env bash
set -euo pipefail
ENVIRONMENT=${1:?environment required}
echo "Connect this adapter to the approved hosting provider for $ENVIRONMENT."
# Recommended: immutable build, migration gate, canary traffic, health check, then promotion.
