# Debian trixie-slim with a headless-capable chromium and a few CLI tools,
# installed from one dated snapshot.debian.org.
#
# This image is published publicly. It must contain only public Debian
# packages: never COPY/ADD files, mount secrets, or add build args beyond
# DEBIAN_SNAPSHOT.
#
# chromium carries no version constraint, so without the snapshot pin every
# rebuild floats to whatever trixie currently ships. That has bitten before:
# trixie's chromium 150.0.7871.46 crashed on launch in containers (SIGILL before
# exposing its DevTools endpoint), while 149 worked. Pinning apt to a dated
# snapshot makes the whole package set, chromium included, reproducible.
# trixie-updates is deliberately left out: the snapshot freezes it anyway, and
# trixie + trixie-security is the smallest set that carries security fixes.
#
# Tradeoff: the pin freezes security updates for every package at the snapshot
# date, since debian-security is pinned to the same date. DEBIAN_SNAPSHOT must
# be advanced periodically, not only when chromium breaks; the monthly
# snapshot-bump workflow validates a candidate and opens a reminder issue.
# The snapshot Release files are still GPG-verified against the baked-in
# debian-archive-keyring; Check-Valid-Until=false only bypasses the freshness
# window (snapshots are intentionally old), and plain http is safe because apt's
# trust is signature-based (ca-certificates is not yet installed at update time,
# so https would not verify here anyway).
#
# The trailing smoke check fails the build if chromium is missing or can't
# render a page headless with --no-sandbox (`--version` alone passed even for
# the broken 150).
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

LABEL org.opencontainers.image.source="https://github.com/oalders/trixie-chromium-base"

ARG DEBIAN_SNAPSHOT=20261001T000000Z

# Persisted (not one-off -o flags) so a derived image that runs apt-get update
# against the same snapshot works: snapshot Release files are past Valid-Until.
RUN printf 'Acquire::Retries "10";\nAcquire::Check-Valid-Until "false";\n' \
      > /etc/apt/apt.conf.d/99snapshot

# The base is digest-pinned; upgrading from the snapshot brings its packages up
# to at least the snapshot's versions (apt never downgrades a newer base).
RUN printf 'deb http://snapshot.debian.org/archive/debian/%s/ trixie main\ndeb http://snapshot.debian.org/archive/debian-security/%s/ trixie-security main\n' \
      "$DEBIAN_SNAPSHOT" "$DEBIAN_SNAPSHOT" > /etc/apt/sources.list \
    && rm -f /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    bash \
    sqlite3 \
    ca-certificates \
    chromium \
    curl \
    jq \
    lynx \
    && rm -rf /var/lib/apt/lists/* \
    && command -v chromium \
    && chromium --no-sandbox --headless=new --dump-dom about:blank > /dev/null
