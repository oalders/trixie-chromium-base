#!/usr/bin/env bash
#
# tag-outputs.sh — print the publish workflow's step outputs for <owner/repo>
# as `key=value` lines (append them to $GITHUB_OUTPUT):
#   snapshot=<DEBIAN_SNAPSHOT default>
#   image=ghcr.io/<owner/repo, lowercased>:<tag from image-tag.sh>
# The image name is lowercased because registries reject uppercase names.
set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> [Dockerfile]}"
DOCKERFILE="${2:-Dockerfile}"
dir="$(dirname "$0")"

snapshot="$(bash "$dir/snapshot-current.sh" "$DOCKERFILE")"
tag="$(bash "$dir/image-tag.sh" "$DOCKERFILE")"
echo "snapshot=$snapshot"
echo "image=ghcr.io/${REPO,,}:$tag"
