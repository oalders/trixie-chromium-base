#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    S="$BATS_TEST_DIRNAME/../scripts"
}

@test "candidate (no or empty arg) is the first of the month, computed in UTC" {
    # Shim date to record its args, so dropping -u fails on a UTC runner too.
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    real_date="$(command -v date)"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$BATS_TEST_TMPDIR/date-args"\nexec %s "$@"\n' "$real_date" > "$BATS_TEST_TMPDIR/bin/date"
    chmod +x "$BATS_TEST_TMPDIR/bin/date"
    for arg in '' none; do
        if [ "$arg" = none ]; then
            PATH="$BATS_TEST_TMPDIR/bin:$PATH" run bash "$S/snapshot-candidate.sh"
        else
            PATH="$BATS_TEST_TMPDIR/bin:$PATH" run bash "$S/snapshot-candidate.sh" ""
        fi
        [ "$status" -eq 0 ]
        [[ "$output" =~ ^[0-9]{6}01T000000Z$ ]]
    done
    [ "$(cat "$BATS_TEST_TMPDIR/date-args")" = "$(printf -- '-u +%%Y%%m01T000000Z\n-u +%%Y%%m01T000000Z')" ]
}

@test "candidate echoes a valid override" {
    run bash "$S/snapshot-candidate.sh" 20260801T000000Z
    [ "$status" -eq 0 ]
    [ "$output" = 20260801T000000Z ]
}

@test "candidate rejects malformed overrides, multiline included" {
    for bad in 2026-08-01 garbage "$(printf 'evil\n20260101T000000Z')"; do
        run bash "$S/snapshot-candidate.sh" "$bad"
        [ "$status" -ne 0 ]
    done
}

@test "should-proceed: dispatch always, schedule only when changed" {
    run bash "$S/snapshot-should-proceed.sh" workflow_dispatch A A
    [ "$status" -eq 0 ]
    [ "$output" = true ]
    run bash "$S/snapshot-should-proceed.sh" schedule A A
    [ "$status" -eq 0 ]
    [ "$output" = false ]
    run bash "$S/snapshot-should-proceed.sh" schedule B A
    [ "$output" = true ]
}

@test "should-proceed fails on a usage error instead of printing a decision" {
    for args in "schedule A" "schedule A B C"; do
        # shellcheck disable=SC2086 # deliberate word splitting into args
        run --separate-stderr bash "$S/snapshot-should-proceed.sh" $args
        [ "$status" -eq 2 ]
        [ -z "$output" ]
    done
}

@test "current prints the uncommented DEBIAN_SNAPSHOT default" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf '%s\n' 'FROM scratch' '# ARG DEBIAN_SNAPSHOT=20200101T000000Z' 'ARG FOO=1' \
        'ARG DEBIAN_SNAPSHOT_X=20210101T000000Z' 'ARG DEBIAN_SNAPSHOT=20260101T000000Z' > "$f"
    run bash "$S/snapshot-current.sh" "$f"
    [ "$status" -eq 0 ]
    [ "$output" = 20260101T000000Z ]
}

@test "current rejects a quoted or malformed default" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    for line in 'ARG DEBIAN_SNAPSHOT="20260101T000000Z"' 'ARG DEBIAN_SNAPSHOT=latest'; do
        printf 'FROM scratch\n%s\n' "$line" > "$f"
        run bash "$S/snapshot-current.sh" "$f"
        [ "$status" -ne 0 ]
        [[ "$output" == *"expected YYYYMMDDTHHMMSSZ"* ]]
    done
}

@test "the real Dockerfile's pin parses and is a valid candidate" {
    run bash "$S/snapshot-current.sh" "$BATS_TEST_DIRNAME/../Dockerfile"
    [ "$status" -eq 0 ]
    pin="$output"
    run bash "$S/snapshot-candidate.sh" "$pin"
    [ "$status" -eq 0 ]
    [ "$output" = "$pin" ]
}

@test "current fails loudly without a DEBIAN_SNAPSHOT or a file" {
    f="$BATS_TEST_TMPDIR/Dockerfile"
    printf 'FROM scratch\n' > "$f"
    run bash "$S/snapshot-current.sh" "$f"
    [ "$status" -ne 0 ]
    [[ "$output" == *"DEBIAN_SNAPSHOT not found"* ]]
    run bash "$S/snapshot-current.sh" "$BATS_TEST_TMPDIR/missing"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found at"* ]]
}

# Stub gh: `issue list` prints $GH_LIST (or fails with $GH_LIST_EXIT); every
# call is logged, one argument per line, to $BATS_TEST_TMPDIR/gh-calls.
stub_gh() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" '--' >> "$BATS_TEST_TMPDIR/gh-calls"
if [ "$1 $2" = "issue list" ]; then
    [ "${GH_LIST_EXIT:-0}" -eq 0 ] || exit "$GH_LIST_EXIT"
    printf '%s' "$GH_LIST"
fi
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/gh"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

remind() {
    run --separate-stderr bash "$S/open-reminder-issue.sh" o/r C1 C0 "$1" https://run
}

# Succeeds if <a> is immediately followed by <b> in the gh call log.
adjacent() {
    grep -Fx -A1 -- "$1" "$BATS_TEST_TMPDIR/gh-calls" | grep -Fxq -- "$2"
}

@test "reminder opens a validated issue when the build passed" {
    stub_gh
    GH_LIST='[]' remind success
    [ "$status" -eq 0 ]
    adjacent list --repo && adjacent --repo o/r && adjacent --state open
    adjacent --author app/github-actions
    adjacent issue create && adjacent create --repo
    [ "$(grep -cFx -- o/r "$BATS_TEST_TMPDIR/gh-calls")" -eq 2 ]
    grep -A6 -Fx create "$BATS_TEST_TMPDIR/gh-calls" | grep -Fxq -- --body
    adjacent --title 'DEBIAN_SNAPSHOT bump: candidate C1 validated (chromium launches)'
    grep -Fq 'to `C1`' "$BATS_TEST_TMPDIR/gh-calls"
    grep -Fq -- '- Current default: `C0`' "$BATS_TEST_TMPDIR/gh-calls"
    grep -Fq 'Run: https://run' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder opens a FAILED issue for any non-success outcome" {
    stub_gh
    for outcome in failure skipped cancelled; do
        GH_LIST='[]' remind "$outcome"
        [ "$status" -eq 0 ]
    done
    [ "$(grep -cx 'DEBIAN_SNAPSHOT bump: candidate C1 FAILED build/smoke check' "$BATS_TEST_TMPDIR/gh-calls")" -eq 3 ]
    for outcome in failure skipped cancelled; do
        grep -Fq "(build outcome: \`$outcome\`)" "$BATS_TEST_TMPDIR/gh-calls"
    done
    grep -Fq 'Keep `C0`' "$BATS_TEST_TMPDIR/gh-calls"
    grep -Fq 'tools package set failed to resolve' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder says no bump is needed when the current pin is re-validated" {
    stub_gh
    GH_LIST='[]' run --separate-stderr bash "$S/open-reminder-issue.sh" o/r C0 C0 success https://run
    [ "$status" -eq 0 ]
    grep -qx 'DEBIAN_SNAPSHOT C0 re-validated (already current)' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder reports FAILED, not re-validated, when the current pin fails" {
    stub_gh
    GH_LIST='[]' run --separate-stderr bash "$S/open-reminder-issue.sh" o/r C0 C0 failure https://run
    [ "$status" -eq 0 ]
    grep -qx 'DEBIAN_SNAPSHOT bump: candidate C0 FAILED build/smoke check' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder skips when the exact title is already open" {
    stub_gh
    GH_LIST='[{"title":"DEBIAN_SNAPSHOT bump: candidate C1 validated (chromium launches)"}]' remind success
    [ "$status" -eq 0 ]
    [ -f "$BATS_TEST_TMPDIR/gh-calls" ]
    run ! grep -qx 'create' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder ignores near-miss titles" {
    stub_gh
    GH_LIST='[{"title":"DEBIAN_SNAPSHOT bump: candidate C1 validated"}]' remind success
    [ "$status" -eq 0 ]
    grep -qx 'create' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder fails, without creating, when listing issues fails or is not JSON" {
    stub_gh
    GH_LIST_EXIT=1 remind success
    [ "$status" -ne 0 ]
    GH_LIST='not json' remind success
    [ "$status" -ne 0 ]
    [ -f "$BATS_TEST_TMPDIR/gh-calls" ]
    run ! grep -qx 'create' "$BATS_TEST_TMPDIR/gh-calls"
}

@test "reminder fails on a usage error or a failed issue create" {
    stub_gh
    run --separate-stderr bash "$S/open-reminder-issue.sh" o/r C1 C0 success
    [ "$status" -eq 2 ]
    printf '#!/usr/bin/env bash\necho "$2" >> "$BATS_TEST_TMPDIR/gh-calls"\n[ "$2" = list ] && { echo "[]"; exit 0; }\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/gh"
    rm -f "$BATS_TEST_TMPDIR/gh-calls"
    remind success
    [ "$status" -ne 0 ]
    grep -qx create "$BATS_TEST_TMPDIR/gh-calls"
}
