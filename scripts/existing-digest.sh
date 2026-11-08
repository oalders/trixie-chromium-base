#!/usr/bin/env bash
#
# existing-digest.sh — print the manifest digest of an already published image,
# or nothing if the tag doesn't exist. Any other lookup failure exits non-zero,
# so the publish workflow never rebuilds (and moves) an existing tag because of
# a registry or auth blip.
set -euo pipefail

IMAGE="${1:?usage: $0 <image>}"
err="$(mktemp)"
trap 'rm -f "$err"' EXIT

if out="$(docker buildx imagetools inspect "$IMAGE" --format '{{json .Manifest}}' 2>"$err")"; then
    digest="$(jq -r '.digest // empty' <<<"$out")"
    if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        echo "error: no manifest digest for '$IMAGE' in: $out" >&2
        exit 1
    fi
    echo "$digest"
# containerd's resolver reports a missing tag as "<ref>: not found" (matched on
# our ref so a proxy's "not found" isn't tag-absent); registries may send OCI codes.
elif grep -Fq -- "$IMAGE: not found" "$err" || grep -Eq 'MANIFEST_UNKNOWN|NAME_UNKNOWN' "$err"; then
    exit 0
else
    cat "$err" >&2
    exit 1
fi
