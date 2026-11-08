#!/usr/bin/env bash
#
# snapshot-should-proceed.sh — print whether the snapshot-bump workflow runs
# its build + issue steps: `true` for a manual dispatch (always re-validates)
# or when candidate != current, else `false`. Exits 2 on a usage error, so a
# broken call fails the step instead of reading as "skip".
#
# Usage: snapshot-should-proceed.sh <event_name> <candidate> <current>
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: snapshot-should-proceed.sh <event_name> <candidate> <current>" >&2
    exit 2
fi

if [ "$1" = "workflow_dispatch" ] || [ "$2" != "$3" ]; then
    echo true
else
    echo false
fi
