# Changelog

All notable changes to this project are documented here.

## 0.1.7 - 2026-09-12

- Fixed a startup regression introduced in 0.1.6: `gateway.publicOrigin` was being populated with the HTTP LAN Control UI origin, but OpenClaw accepts plaintext `publicOrigin` only for loopback hosts and requires HTTPS for non-loopback origins.
- Removed `gateway.publicOrigin` from the generated OpenClaw configuration. `control_ui_origin` is now used only as `gateway.controlUi.allowedOrigins`, which is the correct setting for browser access from the local network.
- Kept the HAOS browser pairing workflow based on local `devices list` / `devices approve <requestId>` state.
- Removed the obsolete dedicated 0.1.6 GitHub Actions workflow so only the main ARM64 build/publish workflow produces release images.

## 0.1.6 - 2026-09-12

- Added a HAOS-friendly browser pairing workflow using OpenClaw's official `devices list` and `devices approve <requestId>` commands.
- Added `pairing_mode` to watch for pending Control UI browser requests and print their request IDs in the app log.
- Added `approve_pairing_request` to approve one exact pending request after operator review.
- Introduced `gateway.publicOrigin` from the configured Control UI origin; this caused an HTTP LAN validation regression and is corrected in 0.1.7.
- Kept Gateway authentication sourced from the official `OPENCLAW_GATEWAY_TOKEN` environment variable.
- Fixed LM Studio API key projection so the configured key is read from the runtime environment.
- Added `clear_internal_logs_on_start` as a safe one-shot cleanup for OpenClaw's own temporary/internal log files; Supervisor logs remain untouched so no additional Home Assistant privileges are required.
- Added detailed English and Italian descriptions for every HAOS configuration option.
- Replaced host-specific defaults with generic required values so no private LAN IP, model ID, API key, or Gateway secret is committed to the public repository.
- Added the official OpenClaw lobster icon from the upstream OpenClaw repository for the Home Assistant app store entry.
- No bootstrap token or Gateway secret is printed by the pairing workflow.

## 0.1.5 - 2026-09-12

- Reduced the inherited OpenClaw Docker healthcheck interval from 3 minutes to 15 seconds for faster HAOS readiness detection.
- Kept the official OpenClaw `dist/docker-healthcheck.js` probe and `/healthz` behavior.
- Added a 20-second healthcheck start period and 3 retries.

## 0.1.4 - 2026-09-12

- Fixed LM Studio model configuration for OpenClaw 2026.9.4 by adding the required `name` field alongside `id`.
- Kept LM Studio configured as an OpenAI-compatible provider using `/v1` and `openai-completions`.

## 0.1.3 - 2026-09-12

- Fixed HAOS `/data` permissions at container runtime.
- The wrapper now starts briefly as root to prepare the app-owned `/data` volume, then drops privileges to the upstream `node` user with `gosu` before OpenClaw starts.
- Preserved the upstream non-root runtime model for OpenClaw.

## 0.1.2 - 2026-09-12

- Switched HAOS installation from local Raspberry Pi image builds to a prebuilt ARM64 image published on GitHub Container Registry.
- Added `image: ghcr.io/making-lemonade/openclaw-haos-addon` to the HAOS app configuration.
- Updated GitHub Actions to build and publish ARM64 images to GHCR.

## 0.1.1 - 2026-09-12

- Hardened the Home Assistant app configuration.
- Disabled host networking, Docker API, Home Assistant API, Supervisor API, hardware access, and privileged mode.
- Kept normal container networking so OpenClaw can access the LAN and Internet.
- Limited persistent app data to HAOS `/data`.

## 0.1.0 - 2026-09-12

- Initial Home Assistant OS app wrapper for OpenClaw on Raspberry Pi 5 (`aarch64`).
- Based on the official OpenClaw container image.
- Added LM Studio LAN configuration and gateway token authentication.
