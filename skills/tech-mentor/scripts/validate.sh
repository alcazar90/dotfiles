#!/usr/bin/env bash
# validate.sh — checks referential integrity of a tech-mentor plan.yaml
# Usage: ./validate.sh plan.yaml
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

PLAN="${1:-plan.yaml}"

yq -o=json . "$PLAN" | jq -r '
  [.contributions[].id] as $ids |
  [.components[].id] as $comps |
  (
    [.contributions[] | select(.in_reply_to != null and ([.in_reply_to] - $ids | length > 0))
      | "broken in_reply_to: \(.id) -> \(.in_reply_to)"]
    +
    [.contributions[] | .depends_on[]? as $d | select([$d] - $ids | length > 0)
      | "broken depends_on in \(.id) -> \($d)"]
    +
    [.contributions[] | select([.component] - $comps | length > 0)
      | "unknown component in \(.id) -> \(.component)"]
  ) as $errors |
  if ($errors | length) == 0 then "all references valid" else $errors[] end
'
