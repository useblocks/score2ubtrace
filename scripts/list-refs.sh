#!/usr/bin/env bash
# Emit a JSON array of refs to publish: main + tags strictly newer than TAG_MIN.
# Usage:
#   list-refs.sh              # full matrix
#   list-refs.sh <ref>        # single-ref override (workflow_dispatch input)
set -euo pipefail

DISPATCH_REF="${1:-}"
if [[ -n "${DISPATCH_REF}" ]]; then
  jq -nc --arg r "${DISPATCH_REF}" '[$r]'
  exit 0
fi

TAG_MIN="${TAG_MIN:-v0.5.5}"

tags="$(gh api repos/eclipse-score/score/tags --paginate --jq '.[].name')"

newer="$(printf '%s\n%s\n' "${TAG_MIN}" "${tags}" \
  | sort -V \
  | awk -v cut="${TAG_MIN}" '
      seen && $0 != cut && index($0, cut "-") != 1 { print }
      $0 == cut { seen = 1 }
    ')"

printf 'main\n%s\n' "${newer}" \
  | grep -v '^$' \
  | jq -Rn '[inputs]' -c
