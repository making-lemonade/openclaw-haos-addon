# OpenClaw HAOS Add-on

Home Assistant OS add-on for running the official OpenClaw gateway on a Raspberry Pi 5 (`aarch64`) while using LM Studio on another machine on the local network.

## Security model

- Official OpenClaw image only, pinned to version `2026.9.4` and an ARM64 image digest.
- Runs as the upstream non-root `node` user after image setup.
- Normal container networking is enabled: OpenClaw can reach the Internet and devices on the LAN such as LM Studio.
- `host_network` is disabled, so OpenClaw does not share the HAOS host network namespace.
- No Docker API access.
- No Home Assistant API or Supervisor API access.
- No `/config`, `/share`, `/media`, USB, GPIO, UART, udev or other host mounts.
- No privileged Linux capabilities requested.
- Default Home Assistant AppArmor confinement remains enabled.
- Only persistent writable storage is the standard Home Assistant app `/data` volume.
- Gateway authentication is mandatory; the add-on refuses to start with the placeholder token.

This is container isolation, not VM isolation. OpenClaw and Home Assistant still share the HAOS host kernel.

## Repository visibility

Home Assistant Supervisor clones custom app repositories directly from the configured Git URL. This repository should therefore be public unless you have separately configured a supported authenticated Git mechanism. No credentials or runtime secrets are stored in this repository; LM Studio credentials and the OpenClaw gateway token are stored in the Home Assistant app options under `/data`.

## Install

In Home Assistant: **Settings → Apps → App store → ⋮ → Repositories** and add:

`https://github.com/making-lemonade/openclaw-haos-addon`

Then install **OpenClaw**.

Before first start configure the app options. See `openclaw/DOCS.md`.

## Upstream provenance

The Dockerfile is based on the official OpenClaw GitHub Container Registry image:

`ghcr.io/openclaw/openclaw:2026.9.4-arm64`

The image is additionally pinned by SHA-256 digest in `openclaw/Dockerfile` so a moved tag cannot silently replace the base image.

Sources:
- OpenClaw: https://github.com/openclaw/openclaw
- OpenClaw LM Studio docs: https://docs.openclaw.ai/providers/lmstudio
- Home Assistant app docs: https://developers.home-assistant.io/docs/apps/configuration/
