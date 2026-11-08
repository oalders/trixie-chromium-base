#!/usr/bin/env bash
#
# image-tag.sh — print the image tag for a Dockerfile (default: ./Dockerfile):
# <DEBIAN_SNAPSHOT>-<first 12 hex of its sha256>, so any change to the file
# publishes a new tag instead of moving an existing one.
set -euo pipefail

DOCKERFILE="${1:-Dockerfile}"
snapshot="$(bash "$(dirname "$0")/snapshot-current.sh" "$DOCKERFILE")"
echo "$snapshot-$(sha256sum "$DOCKERFILE" | cut -c1-12)"
