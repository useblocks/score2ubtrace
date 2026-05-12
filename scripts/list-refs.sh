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

# sort -V orders pre-releases (v0.5.5-rc.1) AFTER the release (v0.5.5), but
# semver ranks them strictly before. The second awk guard drops any post-cutoff
# line whose prefix is "<cutoff>-..." so pre-releases of the cutoff itself are
# correctly excluded. Pre-releases of newer versions (v0.5.6-alpha.1) and
# numerically-greater tags (v0.5.50) pass through.
newer="$(printf '%s\n%s\n' "${TAG_MIN}" "${tags}" \
  | sort -V \
  | awk -v cut="${TAG_MIN}" '
      seen && $0 != cut && index($0, cut "-") != 1 { print }
      $0 == cut { seen = 1 }
    ')"

printf 'main\n%s\n' "${newer}" \
  | grep -v '^$' \
  | jq -Rn '[inputs]' -c
