# CLAUDE.md

This repo publishes one public container image,
`ghcr.io/oalders/trixie-chromium-base`, built from `Dockerfile`. See
`README.md` for how it is used and updated.

## This repo and its image are public

Everything committed here, and everything baked into the image, is public.

- Never mention other projects, private repos, hostnames, issue numbers from
  elsewhere, or why a downstream consumer needs a change. Describe changes in
  terms of this image only.
- The image contains only public Debian packages. Don't add `COPY`/`ADD`,
  secret mounts, or build args beyond `DEBIAN_SNAPSHOT`.

## Published tags are immutable by convention

Consumers are told to pin by digest (`README.md`). The tag embeds a hash of `Dockerfile`, so any
edit to it publishes a new tag; never retag, delete, or force-push an existing
one, and never weaken `scripts/existing-digest.sh`'s fail-closed lookup.

## Workflow logic lives in scripts

Workflow `run:` steps may only invoke a `scripts/*.sh` script (or, in
`test.yml`, the test and lint tools), take inputs from `env:`, append
`name=$(script)` lines to `$GITHUB_OUTPUT`, and echo log lines. Any condition,
parsing or string manipulation goes in a script. Add or update a bats test in
`tests/` (stub `docker`/`gh` on `PATH`) for any new or changed script.
CI (`test.yml`) runs `bats tests/` and `shellcheck scripts/*.sh`; run both
before committing.
