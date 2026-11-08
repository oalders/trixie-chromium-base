#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    S="$BATS_TEST_DIRNAME/../scripts"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/docker-args"
printf '%s' "${STUB_STDOUT:-}"
printf '%s' "${STUB_STDERR:-}" >&2
exit "${STUB_EXIT:-0}"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/docker"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    DIGEST="sha256:$(printf 'a%.0s' {1..64})"
}

@test "image-tag prints <snapshot>-<12 hex of sha256>" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf 'FROM scratch\nARG DEBIAN_SNAPSHOT=20260101T000000Z\n' > "$f"
    run bash "$S/image-tag.sh" "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "20260101T000000Z-$(sha256sum "$f" | cut -c1-12)" ]
}

@test "image-tag changes when the Dockerfile content changes" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf 'FROM scratch\nARG DEBIAN_SNAPSHOT=20260101T000000Z\n' > "$f"
    before="$(bash "$S/image-tag.sh" "$f")"
    printf 'RUN true\n' >> "$f"
    after="$(bash "$S/image-tag.sh" "$f")"
    [ "$before" != "$after" ]
    [[ "$after" == 20260101T000000Z-* ]]
}

@test "tag-outputs prints snapshot and a lowercased image reference" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf 'FROM scratch\nARG DEBIAN_SNAPSHOT=20260101T000000Z\n' > "$f"
    run bash "$S/tag-outputs.sh" Owner/Repo "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'snapshot=20260101T000000Z\nimage=ghcr.io/owner/repo:%s' "$(bash "$S/image-tag.sh" "$f")")" ]
}

@test "image-tag fails for a file without DEBIAN_SNAPSHOT" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf 'FROM scratch\n' > "$f"
    run bash "$S/image-tag.sh" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"DEBIAN_SNAPSHOT"* ]]
}

@test "existing-digest prints the digest of an existing tag" {
    STUB_STDOUT="{\"digest\":\"$DIGEST\"}" run bash "$S/existing-digest.sh" img:tag
    [ "$status" -eq 0 ]
    [ "$output" = "$DIGEST" ]
    [ "$(cat "$BATS_TEST_TMPDIR/docker-args")" = "$(printf '%s\n' buildx imagetools inspect img:tag --format '{{json .Manifest}}')" ]
}

@test "existing-digest prints nothing for a missing tag" {
    for msg in 'ERROR: img:tag: not found' \
               'ERROR: unexpected status: MANIFEST_UNKNOWN: manifest unknown' \
               'ERROR: NAME_UNKNOWN: repository name not known'; do
        STUB_EXIT=1 STUB_STDERR="$msg" run --separate-stderr bash "$S/existing-digest.sh" img:tag
        [ "$status" -eq 0 ]
        [ -z "$output" ]
    done
}

@test "existing-digest fails on other lookup errors" {
    for msg in 'ERROR: failed to authorize: 401 Unauthorized' \
               'ERROR: unexpected status from HEAD request: 503 Service Unavailable' \
               'ERROR: other:tag: not found'; do
        STUB_EXIT=1 STUB_STDERR="$msg" run --separate-stderr bash "$S/existing-digest.sh" img:tag
        [ "$status" -ne 0 ]
        [ "$stderr" = "$msg" ]
    done
}

@test "existing-digest fails when the output has no digest" {
    STUB_STDOUT='{}' run bash "$S/existing-digest.sh" img:tag
    [ "$status" -ne 0 ]
    STUB_STDOUT='not json' run bash "$S/existing-digest.sh" img:tag
    [ "$status" -ne 0 ]
    STUB_STDOUT='{"digest":"sha256:abc"}' run --separate-stderr bash "$S/existing-digest.sh" img:tag
    [ "$status" -ne 0 ]
    [ -z "$output" ]
    [[ "$stderr" == *"img:tag"* ]]
}

@test "print-pin prints the FROM line and appends a fenced copy to the step summary" {
    summary="$BATS_TEST_TMPDIR/summary"
    echo earlier > "$summary"
    GITHUB_STEP_SUMMARY="$summary" run bash "$S/print-pin.sh" img:tag "$DIGEST"
    [ "$status" -eq 0 ]
    [ "$output" = "FROM img:tag@$DIGEST" ]
    [ "$(cat "$summary")" = "$(printf 'earlier\n```dockerfile\nFROM img:tag@%s\n```' "$DIGEST")" ]
}

@test "print-pin works without a step summary" {
    mkdir "$BATS_TEST_TMPDIR/cwd" && cd "$BATS_TEST_TMPDIR/cwd"
    GITHUB_STEP_SUMMARY='' run bash "$S/print-pin.sh" img:tag "$DIGEST"
    [ "$status" -eq 0 ]
    [ "$output" = "FROM img:tag@$DIGEST" ]
    run env -u GITHUB_STEP_SUMMARY bash "$S/print-pin.sh" img:tag "$DIGEST"
    [ "$status" -eq 0 ]
    [ "$output" = "FROM img:tag@$DIGEST" ]
    [ -z "$(ls -A)" ]
}

@test "scripts fail on missing arguments" {
    for s in print-pin existing-digest tag-outputs; do
        run bash "$S/$s.sh"
        [ "$status" -ne 0 ]
    done
}

@test "print-pin fails, writing nothing, without a valid digest" {
    summary="$BATS_TEST_TMPDIR/summary"
    for d in '' sha256:abc "${DIGEST}a" "sha256:$(printf 'A%.0s' {1..64})" "$DIGEST junk"; do
        GITHUB_STEP_SUMMARY="$summary" run bash "$S/print-pin.sh" img:tag "$d"
        [ "$status" -ne 0 ]
    done
    [ ! -e "$summary" ]
}
