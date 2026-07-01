#!/usr/bin/env bash
# query.sh — quick filters over plan.yaml contributions
# Usage:
#   ./query.sh plan.yaml type challenge
#   ./query.sh plan.yaml mentor zhang
#   ./query.sh plan.yaml component calibration_module
# Requires: yq (mikefarah/Go version, NOT the python-yq from pip) + jq
set -euo pipefail

for cmd in yq jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: $cmd is required but not installed." >&2
    [ "$cmd" = "yq" ] && echo "Install the Go version: brew install go-yq" >&2
    [ "$cmd" = "jq" ] && echo "Install with: brew install jq" >&2
    exit 1
  }
done

PLAN="$1"; FIELD="$2"; VALUE="$3"

yq -o=json . "$PLAN" | jq -r --arg f "$FIELD" --arg v "$VALUE" '
  .contributions[] | select(.[$f] == $v) | "[\(.id)] \(.mentor) (\(.type)) — \(.summary)"
'
