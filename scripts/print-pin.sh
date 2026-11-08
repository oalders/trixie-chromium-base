#!/usr/bin/env bash
#
# print-pin.sh — print the digest-pinned FROM line for <image> <digest>, and
# append it to $GITHUB_STEP_SUMMARY when that is set.
set -euo pipefail

IMAGE="${1:?usage: $0 <image> <digest>}"
DIGEST="${2:-}"
if [[ ! "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "error: no valid digest for '$IMAGE' (got '$DIGEST')" >&2
    exit 1
fi

LINE="FROM ${IMAGE}@${DIGEST}"
echo "$LINE"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    # shellcheck disable=SC2016 # literal markdown fence, not an expansion
    printf '```dockerfile\n%s\n```\n' "$LINE" >> "$GITHUB_STEP_SUMMARY"
fi
