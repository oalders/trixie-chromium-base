#!/usr/bin/env bash
#
# snapshot-current.sh — print the `ARG DEBIAN_SNAPSHOT=<value>` default from a
# Dockerfile (default: ./Dockerfile).
set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"

if [ ! -f "$DOCKERFILE" ]; then
    echo "error: Dockerfile not found at '$DOCKERFILE'" >&2
    exit 1
fi

# Anchored so a commented-out `# ARG DEBIAN_SNAPSHOT=old` line can't win.
value="$(grep -E '^[[:space:]]*ARG[[:space:]]+DEBIAN_SNAPSHOT=' "$DOCKERFILE" | head -n1 | cut -d= -f2-)" || true

if [ -z "$value" ]; then
    echo "error: ARG DEBIAN_SNAPSHOT not found in '$DOCKERFILE'" >&2
    exit 1
fi
# Quoted or malformed defaults fail here rather than producing a bad tag.
if [[ ! "$value" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
    echo "error: ARG DEBIAN_SNAPSHOT in '$DOCKERFILE' is '$value', expected YYYYMMDDTHHMMSSZ" >&2
    exit 1
fi

echo "$value"
