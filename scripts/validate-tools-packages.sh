#!/usr/bin/env bash
#
# validate-tools-packages.sh — check that the package sets in Dockerfile.tools
# (CGO_PACKAGES and TEST_TOOLS_PACKAGES) resolve in <image>, which should be
# the runtime image built at a candidate snapshot. Each set is checked with a
# simulated install, so nothing is downloaded or installed.
#
# Usage: validate-tools-packages.sh <image> [Dockerfile.tools]
# Exits non-zero if a set is missing, empty, or does not resolve.
set -euo pipefail

IMAGE="${1:?usage: $0 <image> [Dockerfile.tools]}"
DOCKERFILE="${2:-Dockerfile.tools}"

# Read every list before running docker so a bad file never half-validates.
declare -A sets
for name in CGO_PACKAGES TEST_TOOLS_PACKAGES; do
    line="$(grep -m1 "^ARG $name=" "$DOCKERFILE" || true)"
    re="^ARG $name=\"(.*)\"\$"
    if [[ ! "$line" =~ $re ]] || [ -z "${BASH_REMATCH[1]// /}" ]; then
        echo "$DOCKERFILE: missing or empty ARG $name" >&2
        exit 1
    fi
    sets[$name]="${BASH_REMATCH[1]}"
done

for name in CGO_PACKAGES TEST_TOOLS_PACKAGES; do
    echo "Checking $name in $IMAGE"
    # The list is deliberately word-split into separate arguments.
    # shellcheck disable=SC2086
    docker run --rm "$IMAGE" sh -c \
        'apt-get update && apt-get install -y --simulate --no-install-recommends "$@"' \
        sh ${sets[$name]}
done
