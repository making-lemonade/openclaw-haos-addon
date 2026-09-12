#!/bin/sh
set -eu

OPTIONS=/data/options.json
STATE=/data/.openclaw
WORKSPACE="$STATE/workspace"

# HAOS mounts /data at runtime. Prepare the private app volume as root, then
# restart this script as the upstream non-root node user (uid/gid 1000).
if [ "$(id -u)" = "0" ]; then
  mkdir -p "$WORKSPACE"
  chown -R node:node /data
  exec gosu node:node "$0" "$@"
fi

mkdir -p "$WORKSPACE"

read_opt() {
  key="$1"
  node -e 'const fs=require("fs"); const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); const v=o[process.argv[2]]; if (v !== undefined && v !== null) process.stdout.write(String(v));' "$OPTIONS" "$key"
}

LM_STUDIO_URL="$(read_opt lm_studio_url)"
LM_STUDIO_MODEL="$(read_opt lm_studio_model)"
LM_STUDIO_API_KEY="$(read_opt lm_studio_api_key)"
GATEWAY_TOKEN="$(read_opt gateway_token)"
CONTROL_UI_ORIGIN="$(read_opt control_ui_origin)"
LOG_LEVEL="$(read_opt log_level)"
PAIRING_MODE="$(read_opt pairing_mode)"
APPROVE_PAIRING_REQUEST="$(read_opt approve_pairing_request)"

if [ -z "$LM_STUDIO_URL" ] || [ -z "$LM_STUDIO_MODEL" ]; then
  echo "ERROR: configure lm_studio_url and lm_studio_model in the app options."
  exit 1
fi

if [ -z "$GATEWAY_TOKEN" ]; then
  echo "ERROR: configure gateway_token with a long random value before starting OpenClaw."
  exit 1
fi

if [ -z "$CONTROL_UI_ORIGIN" ]; then
  echo "ERROR: configure control_ui_origin with the exact browser origin used for the Control UI."
  exit 1
fi

if [ -z "$LOG_LEVEL" ]; then
  LOG_LEVEL="warn"
fi

export LM_API_TOKEN="$LM_STUDIO_API_KEY"
export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"
export OPENCLAW_LOG_LEVEL="$LOG_LEVEL"

node <<'NODE'
const fs = require('fs');
const options = JSON.parse(fs.readFileSync('/data/options.json', 'utf8'));
const model = options.lm_studio_model;
const provider = {
  baseUrl: options.lm_studio_url,
  api: 'openai-completions',
  params: { preload: false },
  models: [{ id: model, name: model }]
};
if (options.lm_studio_api_key) provider.apiKey = process.env.LM_API_TOKEN;
const cfg = {
  gateway: {
    mode: 'local',
    bind: 'lan',
    port: 18789,
    auth: { mode: 'token' },
    controlUi: {
      enabled: true,
      allowedOrigins: [options.control_ui_origin]
    },
    terminal: { enabled: false }
  },
  agents: {
    defaults: {
      model: { primary: `lmstudio/${model}` },
      models: { [`lmstudio/${model}`]: { alias: 'Local' } }
    }
  },
  models: { providers: { lmstudio: provider } }
};
fs.mkdirSync('/data/.openclaw/workspace', { recursive: true });
fs.writeFileSync('/data/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2), { mode: 0o600 });
NODE

# Normal operation keeps OpenClaw as the direct long-running process.
if [ "$PAIRING_MODE" != "true" ] && [ -z "$APPROVE_PAIRING_REQUEST" ]; then
  exec node dist/index.js gateway --bind lan --port 18789
fi

# Pairing tools need the Gateway running while the CLI inspects local pairing state.
node dist/index.js gateway --bind lan --port 18789 &
GATEWAY_PID=$!

forward_signal() {
  kill -TERM "$GATEWAY_PID" 2>/dev/null || true
  wait "$GATEWAY_PID" 2>/dev/null || true
}
trap forward_signal TERM INT

READY=false
i=0
while [ "$i" -lt 60 ]; do
  if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
    echo "ERROR: OpenClaw Gateway exited before pairing tools were ready."
    wait "$GATEWAY_PID"
    exit $?
  fi
  if node dist/docker-healthcheck.js >/dev/null 2>&1; then
    READY=true
    break
  fi
  i=$((i + 1))
  sleep 1
done

if [ "$READY" != "true" ]; then
  echo "ERROR: OpenClaw Gateway did not become healthy within 60 seconds."
elif [ -n "$APPROVE_PAIRING_REQUEST" ]; then
  echo "OpenClaw: approving the configured browser pairing request..."
  if node openclaw.mjs devices approve "$APPROVE_PAIRING_REQUEST" --json; then
    echo "OpenClaw: pairing request approved. Clear approve_pairing_request after the browser connects."
  else
    echo "ERROR: pairing approval failed. The request may have expired or been superseded; enable pairing_mode and obtain the current requestId."
  fi
elif [ "$PAIRING_MODE" = "true" ]; then
  echo "OpenClaw pairing mode is active for 5 minutes."
  echo "Open the Control UI, enter the Gateway secret, and press Connect."
  echo "Waiting for a pending browser request..."

  i=0
  FOUND=false
  while [ "$i" -lt 100 ]; do
    if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
      echo "ERROR: OpenClaw Gateway exited while waiting for pairing."
      break
    fi

    LIST_JSON="$(node openclaw.mjs devices list --json 2>/dev/null || true)"
    PENDING_JSON="$(LIST_JSON="$LIST_JSON" node -e 'try { const d=JSON.parse(process.env.LIST_JSON || "{}"); const p=Array.isArray(d.pending)?d.pending:[]; if (p.length) process.stdout.write(JSON.stringify(p,null,2)); } catch {}')"

    if [ -n "$PENDING_JSON" ]; then
      echo ""
      echo "============================================================"
      echo "OPENCLAW PENDING BROWSER PAIRING REQUEST(S)"
      echo "$PENDING_JSON"
      echo "Copy the requestId you recognize into approve_pairing_request, save, and restart the app."
      echo "============================================================"
      echo ""
      FOUND=true
      break
    fi

    i=$((i + 1))
    sleep 3
  done

  if [ "$FOUND" != "true" ]; then
    echo "No pending browser pairing request was found within 5 minutes."
  fi
fi

wait "$GATEWAY_PID"
