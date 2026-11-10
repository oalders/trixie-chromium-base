#!/usr/bin/env bash
#
# tools-tag-outputs.sh — print the tools image reference for <owner/repo> as a
# `key=value` line (append it to $GITHUB_OUTPUT):
#   image=ghcr.io/<owner/repo, lowercased>-tools:<runtime tag>-<12 hex of sha256>
# <runtime tag> is the tag of the runtime image named by the file's first FROM,
# and the hash is of the whole file, so editing the file publishes a new tag.
# The image name is lowercased because registries reject uppercase names.
set -euo pipefail

REPO="${1:?usage: $0 <owner/repo> [Dockerfile.tools]}"
DOCKERFILE="${2:-Dockerfile.tools}"

re='^FROM [^:]+:([^@[:space:]]+)@sha256:[0-9a-f]{64}'
from="$(grep -m1 '^FROM ' "$DOCKERFILE" || true)"
if [[ ! "$from" =~ $re ]]; then
    echo "$DOCKERFILE: first FROM must be <image>:<tag>@sha256:<digest>" >&2
    exit 1
fi
runtime_tag="${BASH_REMATCH[1]}"
hash="$(sha256sum "$DOCKERFILE" | cut -c1-12)"
echo "image=ghcr.io/${REPO,,}-tools:$runtime_tag-$hash"
