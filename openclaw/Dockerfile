FROM ghcr.io/openclaw/openclaw:2026.9.4-arm64@sha256:a71d22cd48540486192b584feba0483ced5d3542335d4b68e5358a01b3945eb5

ARG BUILD_VERSION=0.1.0
ARG BUILD_ARCH=aarch64
LABEL io.hass.version="${BUILD_VERSION}" \
      io.hass.type="app" \
      io.hass.arch="${BUILD_ARCH}"

USER root
COPY run.sh /usr/local/bin/openclaw-haos-run
RUN chmod 0755 /usr/local/bin/openclaw-haos-run \
    && mkdir -p /data \
    && chown -R node:node /data

USER node
ENV HOME=/data \
    OPENCLAW_HOME=/data \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    OPENCLAW_CONFIG_DIR=/data/.openclaw \
    OPENCLAW_CONFIG_PATH=/data/.openclaw/openclaw.json \
    OPENCLAW_WORKSPACE_DIR=/data/.openclaw/workspace \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_DISABLE_BONJOUR=1

ENTRYPOINT ["/usr/local/bin/openclaw-haos-run"]
