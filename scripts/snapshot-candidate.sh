#!/usr/bin/env bash
#
# snapshot-candidate.sh — compute (or validate) a DEBIAN_SNAPSHOT candidate.
#
# With no argument it prints the first of the current month in UTC
# (YYYYMM01T000000Z), which keeps the candidate stable within a month. With an
# argument it validates the shape and echoes it back.
set -euo pipefail

OVERRIDE_DATE="${1:-}"

if [ -n "$OVERRIDE_DATE" ]; then
    # Whole-string bash regex (not line-oriented grep) so an embedded newline
    # can't smuggle a valid-looking line past validation.
    if [[ ! "$OVERRIDE_DATE" =~ ^[0-9]{8}T000000Z$ ]]; then
        echo "error: invalid snapshot date '$OVERRIDE_DATE' (expected YYYYMMDDT000000Z)" >&2
        exit 1
    fi
    echo "$OVERRIDE_DATE"
    exit 0
fi

date -u +%Y%m01T000000Z
