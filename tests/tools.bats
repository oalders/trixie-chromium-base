#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    S="$BATS_TEST_DIRNAME/../scripts"
    DIGEST="sha256:$(printf 'a%.0s' {1..64})"
    FROM_LINE="FROM ghcr.io/o/r:20260101T000000Z-aaaaaaaaaaaa@$DIGEST"
}

@test "cgo set is exactly gcc and libc6-dev" {
    grep -Fxq 'ARG CGO_PACKAGES="gcc libc6-dev"' "$BATS_TEST_DIRNAME/../Dockerfile.tools"
}

@test "tools-tag-outputs prints a lowercased tools image" {
    f="$BATS_TEST_TMPDIR/Dockerfile.tools"
    printf '%s\nRUN true\n' "$FROM_LINE" > "$f"
    run bash "$S/tools-tag-outputs.sh" Owner/Repo "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "image=ghcr.io/owner/repo-tools:20260101T000000Z-aaaaaaaaaaaa-$(sha256sum "$f" | cut -c1-12)" ]
}

@test "tools-tag-outputs changes when the file changes" {
    f="$BATS_TEST_TMPDIR/Dockerfile.tools"
    printf '%s\nRUN true\n' "$FROM_LINE" > "$f"
    before="$(bash "$S/tools-tag-outputs.sh" Owner/Repo "$f")"
    printf 'RUN false\n' >> "$f"
    after="$(bash "$S/tools-tag-outputs.sh" Owner/Repo "$f")"
    [ "$before" != "$after" ]
    [[ "$after" == image=ghcr.io/owner/repo-tools:20260101T000000Z-aaaaaaaaaaaa-* ]]
}

@test "tools-tag-outputs fails on a FROM without a digest" {
    f="$BATS_TEST_TMPDIR/Dockerfile.tools"
    printf 'FROM ghcr.io/o/r:tag\n' > "$f"
    run --separate-stderr bash "$S/tools-tag-outputs.sh" Owner/Repo "$f"
    [ "$status" -ne 0 ]
    [[ "$output" != *image=* ]]
    [[ "$stderr" == *FROM* ]]
}
