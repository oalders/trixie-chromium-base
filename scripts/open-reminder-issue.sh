#!/usr/bin/env bash
#
# open-reminder-issue.sh — open the monthly DEBIAN_SNAPSHOT reminder issue,
# unless an open issue with the same title, opened by this workflow, exists.
# Counting only github-actions' issues stops anyone pre-opening the title.
#
# Usage: open-reminder-issue.sh <repo> <candidate> <current> <build outcome> <run url>
# A failed `gh issue list` or unparseable output exits non-zero rather than
# reading as "no issue", which would open a duplicate.
set -euo pipefail

if [ "$#" -ne 5 ]; then
    echo "usage: open-reminder-issue.sh <repo> <candidate> <current> <outcome> <run_url>" >&2
    exit 2
fi
REPO="$1" CANDIDATE="$2" CURRENT="$3" OUTCOME="$4" RUN_URL="$5"

if [ "$OUTCOME" = "success" ] && [ "$CANDIDATE" = "$CURRENT" ]; then
    # A manual dispatch re-validating the current pin: nothing to bump.
    TITLE="DEBIAN_SNAPSHOT ${CANDIDATE} re-validated (already current)"
    BODY="The image still builds at the current pin \`${CURRENT}\` and the chromium launch smoke check passed. No bump needed.

Run: ${RUN_URL}"
elif [ "$OUTCOME" = "success" ]; then
    TITLE="DEBIAN_SNAPSHOT bump: candidate ${CANDIDATE} validated (chromium launches)"
    BODY="The image builds at candidate \`${CANDIDATE}\` and the chromium launch smoke check passed.

- Current default: \`${CURRENT}\`
- Validated candidate: \`${CANDIDATE}\`

**Action:** open a PR bumping \`ARG DEBIAN_SNAPSHOT=\` in \`Dockerfile\` to \`${CANDIDATE}\`. After it merges, the Publish run's summary has the new digest-pinned reference for consumers.

Run: ${RUN_URL}"
else
    # Covers failure and skipped/cancelled: anything but a passing build.
    TITLE="DEBIAN_SNAPSHOT bump: candidate ${CANDIDATE} FAILED build/smoke check"
    BODY="The image did not build at candidate \`${CANDIDATE}\` (build outcome: \`${OUTCOME}\`), or chromium failed its launch smoke check. **Do not bump the pin.** Keep \`${CURRENT}\`; this candidate needs investigation.

- Current default (unchanged): \`${CURRENT}\`
- Failed candidate: \`${CANDIDATE}\`

Run: ${RUN_URL}"
fi

open_issues="$(gh issue list --repo "$REPO" --state open --author app/github-actions --limit 100 --json title)"
count="$(jq --arg t "$TITLE" '[.[] | select(.title == $t)] | length' <<<"$open_issues")"

if [ "$count" -gt 0 ]; then
    echo "An open issue titled '$TITLE' already exists; skipping creation."
else
    gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY"
fi
