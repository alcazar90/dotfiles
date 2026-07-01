#!/usr/bin/env bash
# query.sh — quick filters over plan.yaml contributions
# Usage:
#   ./query.sh plan.yaml type challenge
#   ./query.sh plan.yaml mentor zhang
#   ./query.sh plan.yaml component calibration_module
#   ./query.sh plan.yaml unresolved            # challenges not yet resolved
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

if [ "$FIELD" = "unresolved" ]; then
  yq -o=json . "$PLAN" | jq -r '
    [.contributions[] | select(.resolves != null) | .resolves] as $resolved |
    .contributions[] | select(.type == "challenge" and ([.id] - $resolved | length > 0))
    | "[\(.id)] \(.mentor) (\(.type)) — \(.summary)"
  '
else
  yq -o=json . "$PLAN" | jq -r --arg f "$FIELD" --arg v "$VALUE" '
    .contributions[] | select(.[$f] == $v) | "[\(.id)] \(.mentor) (\(.type)) — \(.summary)"
  '
fi
