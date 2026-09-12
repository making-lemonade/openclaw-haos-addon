FROM ghcr.io/openclaw/openclaw:2026.9.4-arm64@sha256:a71d22cd48540486192b584feba0483ced5d3542335d4b68e5358a01b3945eb5

ARG BUILD_VERSION=0.1.6
ARG BUILD_ARCH=aarch64
LABEL io.hass.version="${BUILD_VERSION}" \
      io.hass.type="app" \
      io.hass.arch="${BUILD_ARCH}"

USER root

# HAOS mounts /data at container start, after image build. The entrypoint must
# therefore begin as root so it can fix ownership of the private app data volume,
# then drop privileges before OpenClaw starts.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /usr/local/bin/openclaw-haos-run
RUN chmod 0755 /usr/local/bin/openclaw-haos-run

ENV HOME=/data \
    OPENCLAW_HOME=/data \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    OPENCLAW_CONFIG_DIR=/data/.openclaw \
    OPENCLAW_CONFIG_PATH=/data/.openclaw/openclaw.json \
    OPENCLAW_WORKSPACE_DIR=/data/.openclaw/workspace \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_DISABLE_BONJOUR=1

# Upstream checks every 3 minutes. HAOS waits on Docker health state, so use a
# faster equivalent probe while keeping the official OpenClaw healthcheck script.
HEALTHCHECK --interval=15s --timeout=10s --start-period=20s --retries=3 \
  CMD ["node", "dist/docker-healthcheck.js"]

ENTRYPOINT ["tini", "-s", "--", "/usr/local/bin/openclaw-haos-run"]
