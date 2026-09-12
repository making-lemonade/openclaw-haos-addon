# OpenClaw add-on configuration

## Required options

### `lm_studio_url`
LAN URL of LM Studio, including `/v1`.

Example: `http://192.168.1.50:1234/v1`

LM Studio must be configured to listen on the LAN, not only on `127.0.0.1`.

### `lm_studio_model`
Exact LM Studio model key, for example `qwen/qwen3.5-9b`.

You can retrieve model keys from the Mac running LM Studio with:

```bash
curl http://127.0.0.1:1234/api/v1/models
```

### `lm_studio_api_key`
Optional LM Studio API token. Leave blank only if LM Studio authentication is disabled.

### `gateway_token`
Required OpenClaw Gateway token. Replace the placeholder with a long random string before first start.

Generate one on a Mac/Linux terminal with:

```bash
openssl rand -hex 32
```

### `control_ui_origin`
Browser origin allowed to access the OpenClaw Control UI. Set this to the URL you actually use for the Raspberry/Home Assistant host and port `18789`.

Example:

`http://192.168.1.20:18789`

## Network

The container exposes TCP port `18789` through Docker bridge networking. `host_network` is disabled.

The only intended outbound connection is from OpenClaw to the LM Studio address you configure. Home Assistant Supervisor does not provide a per-destination egress firewall for apps, so this repository cannot technically enforce that LM Studio is the only reachable LAN host. For stronger isolation, use VLAN/firewall rules outside the container.

## Home Assistant access

This add-on deliberately has:

- `homeassistant_api: false`
- `hassio_api: false`
- `docker_api: false`
- no Home Assistant configuration mount
- no device/hardware mappings

If Home Assistant access is added later, it should be introduced separately and with the minimum token permissions possible.

## Persistence

OpenClaw state and workspace are stored under `/data/.openclaw`, which is the standard private persistent volume assigned by Home Assistant to this app.

## Updating OpenClaw

Do not change the tag alone. Verify the official ARM64 digest for the desired OpenClaw version on GitHub Container Registry and update both the tag and digest in `Dockerfile`, then bump `version` in `config.yaml`.
