#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    S="$BATS_TEST_DIRNAME/../scripts"
    DIGEST="sha256:$(printf 'a%.0s' {1..64})"
    FROM_LINE="FROM ghcr.io/o/r:20260101T000000Z-aaaaaaaaaaaa@$DIGEST"
    # Stub docker, appending one call per invocation (one argument per line,
    # calls separated by a "--" line).
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/docker" <<'STUB'
#!/usr/bin/env bash
{ printf '%s\n' "$@"; echo --; } >> "$BATS_TEST_TMPDIR/docker-calls"
exit "${STUB_EXIT:-0}"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/docker"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
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

write_tools_dockerfile() {
    printf '%s\nARG CGO_PACKAGES="%s"\nARG TEST_TOOLS_PACKAGES="%s"\n' \
        "$FROM_LINE" "$1" "$2" > "$BATS_TEST_TMPDIR/Dockerfile.tools"
}

@test "validate runs one docker check per set" {
    write_tools_dockerfile "gcc libc6-dev" "bats make"
    run bash "$S/validate-tools-packages.sh" img:tag "$BATS_TEST_TMPDIR/Dockerfile.tools"
    [ "$status" -eq 0 ]
    calls="$BATS_TEST_TMPDIR/docker-calls"
    [ "$(grep -c '^--$' "$calls")" -eq 2 ]
    [ "$(grep -cx 'img:tag' "$calls")" -eq 2 ]
    [ "$(grep -c 'apt-get update' "$calls")" -eq 2 ]
    [ "$(grep -c -- '--simulate' "$calls")" -eq 2 ]
    [ "$(grep -c -- '--no-install-recommends' "$calls")" -eq 2 ]
    for p in gcc libc6-dev bats make; do grep -qx "$p" "$calls"; done
}

@test "validate fails when a package can't be resolved" {
    write_tools_dockerfile "gcc" "bats"
    STUB_EXIT=100 run bash "$S/validate-tools-packages.sh" img:tag "$BATS_TEST_TMPDIR/Dockerfile.tools"
    [ "$status" -ne 0 ]
}

@test "validate fails when a package list is missing or empty" {
    f="$BATS_TEST_TMPDIR/Dockerfile.tools"
    printf '%s\nARG TEST_TOOLS_PACKAGES="bats"\n' "$FROM_LINE" > "$f"
    run bash "$S/validate-tools-packages.sh" img:tag "$f"
    [ "$status" -ne 0 ]
    write_tools_dockerfile "" "bats"
    run bash "$S/validate-tools-packages.sh" img:tag "$f"
    [ "$status" -ne 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/docker-calls" ]
}
