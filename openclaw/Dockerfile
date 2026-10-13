FROM ghcr.io/openclaw/openclaw:2026.10.2-arm64@sha256:c885777ddf193f2bbac2ba9d2d8ea0d8a634cce1bfd997ba641cbee21ca5e4f1

ARG BUILD_VERSION=0.1.15
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
    OPENCLAW_DISABLE_BONJOUR=1 \
    OPENCLAW_HAOS_WRAPPER_VERSION=0.1.15 \
    OPENCLAW_UPSTREAM_VERSION=2026.10.2

HEALTHCHECK --interval=15s --timeout=10s --start-period=20s --retries=3 \
  CMD ["node", "dist/docker-healthcheck.js"]

ENTRYPOINT ["tini", "-s", "--", "/usr/local/bin/openclaw-haos-run"]
