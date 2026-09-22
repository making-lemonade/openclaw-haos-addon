## 0.1.14

- Bootstrap the OpenClaw `lmstudio` provider from the HAOS LM Studio URL, model, and optional API key.
- Preserve the configured LM Studio model as the primary agent model when the old Qwen default is still present.

# Changelog

All notable changes to this project are documented here.

## 0.1.13 - 2026-09-13

- Changed Gateway authentication ownership so OpenClaw now persists and owns the native Gateway password.
- Added a first-login bootstrap flow: when no native Gateway password exists, the wrapper seeds it from the optional HAOS `gateway_password` field or generates a strong random password and prints it once in the app log.
- After the first login, changing the Gateway password in the native OpenClaw Control UI is preserved across HAOS restarts and wrapper upgrades.
- Legacy `gateway_token` is now ignored by the wrapper.
- The wrapper no longer exports `OPENCLAW_GATEWAY_TOKEN` or `OPENCLAW_GATEWAY_PASSWORD`, preventing HAOS environment credentials from overriding password changes made in OpenClaw.
- Existing model/provider/agent/tool configuration remains owned by OpenClaw and is preserved.

## 0.1.12 - 2026-09-13

- Switched the HAOS Gateway authentication flow from token mode to password mode.
- Added a new `gateway_password` HAOS option and pass it to OpenClaw only through `OPENCLAW_GATEWAY_PASSWORD`; the password is not stored in `openclaw.json`.
- Existing `gateway_token` values are accepted temporarily as the password when `gateway_password` is still empty, so upgrades are not locked out. After upgrading, set `gateway_password` and clear the legacy token field.
- The wrapper removes any persisted Gateway token/password value from `openclaw.json` and enforces only `gateway.auth.mode: "password"`.
- Model/provider/agent/tool configuration remains owned by native OpenClaw configuration and is not regenerated from HAOS options.

## 0.1.11 - 2026-09-13

- Stopped regenerating OpenClaw model, provider, agent, tool and memory configuration from HAOS app options on every startup.
- OpenClaw now owns and persists its native `openclaw.json` model/provider configuration, editable through the OpenClaw Control UI.
- The HAOS wrapper now limits its config changes to Gateway infrastructure required by the app: LAN bind, port 18789, token auth mode, allowed Control UI origin, and disabled terminal.
- Legacy `lm_studio_url`, `lm_studio_model`, and `lm_studio_api_key` HAOS fields remain only for upgrade compatibility and are ignored by 0.1.11+.
- Added an explicit startup banner showing the running HAOS wrapper version, upstream OpenClaw version, and config file path.
- Added safe startup diagnostics for the configured primary model and provider endpoint without printing credentials.
- Added bounded Gateway shutdown handling so HAOS restarts do not leave OpenClaw draining active work for several minutes before Supervisor force-kills the container.
- No private LAN address, model selection, Gateway token, or user-specific credential was added to the public repository.

## 0.1.10 - 2026-09-12

- Set `models.mode: "replace"` in the generated OpenClaw configuration so the LM Studio endpoint configured in HAOS is the source of truth after every restart.
- Prevented stale provider data from an agent-local persistent `models.json` from preserving an old LM Studio `baseUrl` after the HAOS option changes.
- Kept the existing LM Studio auth marker behavior, output-token cap, loop detection, and JIT/preload settings from 0.1.9.
- No user-specific LAN address or credential was added to the repository.
