# CLAUDE.md

This repo publishes two public container images. See `README.md` for how they
are used and updated.

- `ghcr.io/oalders/trixie-chromium-base`, the runtime image, built from
  `Dockerfile`.
- `ghcr.io/oalders/trixie-chromium-base-tools`, a store of `.deb` closures and
  static binaries that is never run, built from `Dockerfile.tools`.

## This repo and its image are public

Everything committed here, and everything baked into the image, is public.

- Never mention other projects, private repos, hostnames, issue numbers from
  elsewhere, or why a downstream consumer needs a change. Describe changes in
  terms of this image only.
- The runtime image contains only public Debian packages. Don't add
  `COPY`/`ADD`, secret mounts, or build args beyond `DEBIAN_SNAPSHOT` to
  `Dockerfile`.
- The tools image contains only public Debian packages and public release
  binaries. No `COPY`/`ADD` and no secret mounts there either.

## Published tags are immutable by convention

Consumers are told to pin by digest (`README.md`). Each tag embeds a hash of
its Dockerfile (`Dockerfile` or `Dockerfile.tools`), so any edit to one
publishes a new tag; never retag, delete, or force-push an existing one, in
either image, and never weaken `scripts/existing-digest.sh`'s fail-closed lookup.

## Workflow logic lives in scripts

Workflow `run:` steps may only invoke a `scripts/*.sh` script (or, in
`test.yml`, the test and lint tools), take inputs from `env:`, append
`name=$(script)` lines to `$GITHUB_OUTPUT`, and echo log lines. Any condition,
parsing or string manipulation goes in a script. Add or update a bats test in
`tests/` (stub `docker`/`gh` on `PATH`) for any new or changed script.
CI (`test.yml`) runs `bats tests/` and `shellcheck scripts/*.sh`; run both
before committing.
