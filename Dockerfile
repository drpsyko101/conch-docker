# syntax=docker/dockerfile:1

# Conch — a lightweight, zero-dependency shell execution server.
# https://github.com/newo-ether/conch
#
# The runtime image MUST contain a shell (/bin/sh) because Conch executes
# commands through it. Alpine is the smallest base that provides one, and the
# Conch binary is statically linked, so it runs on it with no extra libraries.

# Pin the release to build from. Bump this (or pass --build-arg) to upgrade.
ARG CONCH_VERSION=v1.0.17

# ---------------------------------------------------------------------------
# Builder: download the static binary from GitHub Releases and verify it.
# ---------------------------------------------------------------------------
FROM alpine:3.20 AS builder
ARG CONCH_VERSION
# TARGETARCH is injected by BuildKit (amd64 | arm64 | ...). Fallback keeps
# classic `docker build` working on x86_64 hosts.
ARG TARGETARCH

RUN apk add --no-cache curl ca-certificates \
 && set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    name="conch-linux-${arch}"; \
    base="https://github.com/newo-ether/conch/releases/download/${CONCH_VERSION}"; \
    curl -fsSL "${base}/checksums.txt" -o /tmp/checksums.txt; \
    curl -fsSL "${base}/${name}" -o /tmp/conch; \
    expected="$(awk -v n="$name" '$2==n {print tolower($1); exit}' /tmp/checksums.txt)"; \
    actual="$(sha256sum /tmp/conch | awk '{print tolower($1)}')"; \
    [ -n "$expected" ] || { echo "no checksum found for ${name}"; exit 1; }; \
    [ "$expected" = "$actual" ] || { echo "sha256 mismatch for ${name}"; exit 1; }; \
    install -m 0755 /tmp/conch /usr/local/bin/conch

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
FROM alpine:3.20

# Conch refuses to start without CONCH_API_KEY unless CONCH_ALLOW_NO_AUTH=true.
# Supply CONCH_API_KEY at runtime (see README). These are safe defaults.
ENV CONCH_HOST=0.0.0.0 \
    CONCH_PORT=14216 \
    CONCH_JOB_DIR=/var/lib/conch

# Run as an unprivileged user; give it a writable dir for durable job state.
RUN set -eux; \
    addgroup -S conch; \
    adduser -S -G conch conch; \
    mkdir -p /var/lib/conch; \
    chown -R conch:conch /var/lib/conch

COPY --from=builder /usr/local/bin/conch /usr/local/bin/conch

USER conch
WORKDIR /var/lib/conch

# Single HTTP port for /health, /version, /public-key, /execute, /jobs/*.
EXPOSE 14216

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- "http://127.0.0.1:${CONCH_PORT}/health" | grep -q '"status":"ok"' || exit 1

ENTRYPOINT ["/usr/local/bin/conch"]
