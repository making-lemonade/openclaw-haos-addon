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

if [ -z "$LM_STUDIO_URL" ] || [ -z "$LM_STUDIO_MODEL" ]; then
  echo "ERROR: configure lm_studio_url and lm_studio_model in the add-on options."
  exit 1
fi

if [ -z "$GATEWAY_TOKEN" ] || [ "$GATEWAY_TOKEN" = "CHANGE_ME_TO_A_LONG_RANDOM_TOKEN" ]; then
  echo "ERROR: replace gateway_token with a long random value before starting OpenClaw."
  exit 1
fi

export LM_API_TOKEN="$LM_STUDIO_API_KEY"
export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

node <<'NODE'
const fs = require('fs');
const options = JSON.parse(fs.readFileSync('/data/options.json','utf8'));
const model = options.lm_studio_model;
const provider = {
  baseUrl: options.lm_studio_url,
  api: 'openai-completions',
  params: { preload: false },
  models: [{ id: model, name: model }]
};
if (options.lm_studio_api_key) provider.apiKey = '${LM_API_TOKEN}';
const cfg = {
  gateway: {
    mode: 'local',
    bind: 'lan',
    port: 18789,
    auth: {
      mode: 'token',
      token: '${OPENCLAW_GATEWAY_TOKEN}'
    },
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

exec node dist/index.js gateway --bind lan --port 18789
