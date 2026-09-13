#!/bin/sh
set -eu

OPTIONS=/data/options.json
STATE=/data/.openclaw
WORKSPACE="$STATE/workspace"
CONFIG="$STATE/openclaw.json"

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

GATEWAY_TOKEN="$(read_opt gateway_token)"
CONTROL_UI_ORIGIN="$(read_opt control_ui_origin)"
LOG_LEVEL="$(read_opt log_level)"
PAIRING_MODE="$(read_opt pairing_mode)"
APPROVE_PAIRING_REQUEST="$(read_opt approve_pairing_request)"

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

export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"
export OPENCLAW_LOG_LEVEL="$LOG_LEVEL"

printf '%s\n' "============================================================"
printf 'OpenClaw HAOS wrapper: %s\n' "${OPENCLAW_HAOS_WRAPPER_VERSION:-unknown}"
printf 'OpenClaw upstream: %s\n' "${OPENCLAW_UPSTREAM_VERSION:-unknown}"
printf 'OpenClaw config: %s\n' "$CONFIG"
printf '%s\n' "============================================================"

# OpenClaw owns all model, agent, tool, memory and provider configuration.
# The HAOS wrapper only enforces the Gateway settings needed to expose the
# Control UI safely on the configured LAN origin. Existing OpenClaw config is
# preserved and can be edited through the native Control UI.
node <<'NODE'
const fs = require('fs');
const path = '/data/.openclaw/openclaw.json';
const options = JSON.parse(fs.readFileSync('/data/options.json', 'utf8'));

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

let current = {};
if (fs.existsSync(path)) {
  try {
    current = asObject(JSON.parse(fs.readFileSync(path, 'utf8')));
  } catch (error) {
    console.error(`ERROR: existing OpenClaw config is not valid JSON: ${error.message}`);
    process.exit(1);
  }
}

const existingGateway = asObject(current.gateway);
const auth = { ...asObject(existingGateway.auth), mode: 'token' };
// The Gateway secret is supplied only through OPENCLAW_GATEWAY_TOKEN.
delete auth.token;
delete auth.password;

const next = {
  ...current,
  gateway: {
    ...existingGateway,
    mode: 'local',
    bind: 'lan',
    port: 18789,
    auth,
    controlUi: {
      ...asObject(existingGateway.controlUi),
      enabled: true,
      allowedOrigins: [options.control_ui_origin]
    },
    terminal: {
      ...asObject(existingGateway.terminal),
      enabled: false
    }
  }
};

const nextRaw = `${JSON.stringify(next, null, 2)}\n`;
const oldRaw = fs.existsSync(path) ? fs.readFileSync(path, 'utf8') : '';
if (oldRaw !== nextRaw) {
  fs.writeFileSync(path, nextRaw, { mode: 0o600 });
} else {
  fs.chmodSync(path, 0o600);
}

const legacyModelOptions = [
  options.lm_studio_url,
  options.lm_studio_model,
  options.lm_studio_api_key
].some((value) => typeof value === 'string' && value.trim());
if (legacyModelOptions) {
  console.log('OpenClaw HAOS: legacy lm_studio_* HAOS options are present but ignored in 0.1.11+. Configure providers and models in the OpenClaw Control UI.');
}

const primaryValue = next.agents?.defaults?.model;
const primary = typeof primaryValue === 'string'
  ? primaryValue
  : typeof primaryValue?.primary === 'string'
    ? primaryValue.primary
    : '';
console.log(`OpenClaw configured primary model: ${primary || '(not configured)'}`);

if (primary.includes('/')) {
  const providerId = primary.slice(0, primary.indexOf('/'));
  const provider = next.models?.providers?.[providerId];
  const baseUrl = typeof provider?.baseUrl === 'string' ? provider.baseUrl : '';
  if (baseUrl) {
    console.log(`OpenClaw configured provider endpoint: ${baseUrl}`);
  }
}
NODE

# Keep the Gateway as a child so the wrapper can translate HAOS shutdown into a
# bounded graceful stop. OpenClaw can otherwise drain active work for several
# minutes while Supervisor expects the app to stop much sooner.
node dist/index.js gateway --bind lan --port 18789 &
GATEWAY_PID=$!

shutdown_gateway() {
  trap - TERM INT
  echo "OpenClaw HAOS: shutdown requested."
  kill -TERM "$GATEWAY_PID" 2>/dev/null || true

  i=0
  while kill -0 "$GATEWAY_PID" 2>/dev/null && [ "$i" -lt 8 ]; do
    i=$((i + 1))
    sleep 1
  done

  if kill -0 "$GATEWAY_PID" 2>/dev/null; then
    echo "OpenClaw HAOS: Gateway did not stop within 8 seconds; forcing container shutdown."
    kill -KILL "$GATEWAY_PID" 2>/dev/null || true
  fi

  wait "$GATEWAY_PID" 2>/dev/null || true
  exit 0
}
trap shutdown_gateway TERM INT

# Normal operation: no pairing helper is required. Keep the wrapper alive only
# to forward/limit shutdown; propagate an unexpected Gateway exit code.
if [ "$PAIRING_MODE" != "true" ] && [ -z "$APPROVE_PAIRING_REQUEST" ]; then
  if wait "$GATEWAY_PID"; then
    exit 0
  else
    STATUS=$?
    echo "ERROR: OpenClaw Gateway exited with code $STATUS."
    exit "$STATUS"
  fi
fi

# Pairing tools need the Gateway running while the CLI inspects local pairing state.
READY=false
i=0
while [ "$i" -lt 60 ]; do
  if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
    echo "ERROR: OpenClaw Gateway exited before pairing tools were ready."
    if wait "$GATEWAY_PID"; then
      exit 0
    else
      exit $?
    fi
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

if wait "$GATEWAY_PID"; then
  exit 0
else
  STATUS=$?
  echo "ERROR: OpenClaw Gateway exited with code $STATUS."
  exit "$STATUS"
fi
