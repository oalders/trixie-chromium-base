# trixie-chromium-base

`debian:trixie-slim` plus a headless-capable `chromium`, `bash`, `sqlite3`,
`ca-certificates`, `curl`, `jq` and `lynx`, installed from one dated
[snapshot.debian.org](https://snapshot.debian.org/). The digest-pinned base
layer is upgraded to at least the snapshot's versions.

A downstream build that installs nothing extra never contacts
snapshot.debian.org, so a snapshot outage can't fail it. A derived image that
does run `apt-get update` gets the same snapshot, with retries and the
snapshot's expired `Valid-Until` already configured.

## Using it

**Always pin by digest.** GHCR tags can be overwritten by anyone with write
access to the package, so a tag-only `FROM` is not a pin. The tag is
`<DEBIAN_SNAPSHOT>-<12 hex of the Dockerfile's sha256>`, for example
`20261001T000000Z-0123456789ab`, and each
[Publish](.github/workflows/publish.yml) run on `main` prints the full
reference in its job summary:

```dockerfile
FROM ghcr.io/oalders/trixie-chromium-base:<tag>@sha256:<digest>
```

Published tags are never deleted or rebuilt by the workflow.

The image runs as root, and the build's smoke check launches chromium with
`--no-sandbox`. If you render untrusted pages, run chromium as a non-root user
with its sandbox enabled.

## Updating it

1. Open a PR changing `Dockerfile` (usually `ARG DEBIAN_SNAPSHOT`). The PR
   builds the image, including a chromium launch smoke check, without pushing.
2. Merge. Publish pushes the new tag and prints the reference to pin.

A monthly [reminder](.github/workflows/snapshot-bump.yml) validates the
first-of-month snapshot and opens an issue, since the pin also freezes security
updates. GitHub disables scheduled workflows after 60 days without repository
activity; if the reminders stop, re-enable the workflow or run it by hand.

Dependabot proposes updates to the digest-pinned `debian:trixie-slim` base and
to the workflow actions.

## One-time setup

GHCR creates the package private on its first publish. After that run, set the
package's visibility to **Public** in its settings so anonymous pulls work.

## Tests

```sh
bats tests/
shellcheck scripts/*.sh
```

## License

[MIT](LICENSE)
