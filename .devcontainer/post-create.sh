#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_HELPERS_PATH="$DEVCONTAINER_DIR/config-helpers.cjs"
readonly PNPM_BIN_DIR="/usr/local/share/pnpm/bin"
readonly PNPM_GLOBAL_DIR="/usr/local/share/pnpm-global"
readonly PNPM_CONFIG_DIR="/home/vscode/.config/pnpm"
readonly PNPM_CONFIG_FILE="$PNPM_CONFIG_DIR/config.yaml"
readonly CODEX_CONFIG_PATH="/home/vscode/.codex/config.toml"
readonly CODEX_HOOKS_PATH="/home/vscode/.codex/hooks.json"
readonly COPILOT_HOME_DIR="${COPILOT_HOME:-/home/vscode/.copilot}"
readonly COPILOT_HOOKS_PATH="$COPILOT_HOME_DIR/hooks/context-mode.json"
readonly PERSISTENT_HOME_DIRS=(
  "/home/vscode/.codex"
  "/home/vscode/.copilot"
  "/home/vscode/.config/opencode"
  "/home/vscode/.local/share/opencode"
  "/home/vscode/.local/state/opencode"
  "/home/vscode/.opensrc"
  "/home/vscode/.agents/skills"
)

opencode_config_path() {
  if [[ -f "/home/vscode/.config/opencode/opencode.json" ]]; then
    printf '%s\n' "/home/vscode/.config/opencode/opencode.json"
    return
  fi

  if [[ -f "/home/vscode/.config/opencode/opencode.jsonc" ]]; then
    printf '%s\n' "/home/vscode/.config/opencode/opencode.jsonc"
    return
  fi

  printf '%s\n' "/home/vscode/.config/opencode/opencode.json"
}

gitnexus_bin_path() {
  command -v gitnexus 2>/dev/null || true
}

ensure_persistent_home_ownership() {
  local directory

  for directory in "${PERSISTENT_HOME_DIRS[@]}"; do
    sudo mkdir -p "$directory"
    sudo chown -R vscode:vscode "$directory"
  done
}

ensure_pnpm_user_config() {
  sudo mkdir -p "$PNPM_CONFIG_DIR"
  printf 'globalBinDir: %s\nglobalDir: %s\n' "$PNPM_BIN_DIR" "$PNPM_GLOBAL_DIR" | sudo tee "$PNPM_CONFIG_FILE" >/dev/null
  sudo chown -R vscode:vscode "$PNPM_CONFIG_DIR"
}

ensure_codex_context_mode_config() {
  local temp_file

  mkdir -p "$(dirname "$CODEX_CONFIG_PATH")"

  if [[ ! -f "$CODEX_CONFIG_PATH" ]]; then
    cat >"$CODEX_CONFIG_PATH" <<'EOF'
[features]
hooks = true
plugin_hooks = true

[mcp_servers.context-mode]
command = "context-mode"

[mcp_servers.context-mode.env]
CONTEXT_MODE_PLATFORM = "codex"
EOF
    return
  fi

  temp_file="$(mktemp)"

  awk '
    BEGIN {
      in_features = 0
      saw_features = 0
      saw_hooks = 0
      saw_plugin_hooks = 0
    }

    /^\[features\]$/ {
      saw_features = 1
      in_features = 1
      print
      next
    }

    /^\[/ {
      if (in_features == 1) {
        if (saw_hooks == 0) {
          print "hooks = true"
        }
        if (saw_plugin_hooks == 0) {
          print "plugin_hooks = true"
        }
        in_features = 0
      }

      print
      next
    }

    {
      if (in_features == 1) {
        if ($0 ~ /^hooks = /) {
          saw_hooks = 1
        }
        if ($0 ~ /^plugin_hooks = /) {
          saw_plugin_hooks = 1
        }
      }

      print
    }

    END {
      if (in_features == 1) {
        if (saw_hooks == 0) {
          print "hooks = true"
        }
        if (saw_plugin_hooks == 0) {
          print "plugin_hooks = true"
        }
      }

      if (saw_features == 0) {
        print ""
        print "[features]"
        print "hooks = true"
        print "plugin_hooks = true"
      }
    }
  ' "$CODEX_CONFIG_PATH" >"$temp_file"

  mv "$temp_file" "$CODEX_CONFIG_PATH"

  if ! grep -Fq '[mcp_servers.context-mode]' "$CODEX_CONFIG_PATH"; then
    cat >>"$CODEX_CONFIG_PATH" <<'EOF'

[mcp_servers.context-mode]
command = "context-mode"

[mcp_servers.context-mode.env]
CONTEXT_MODE_PLATFORM = "codex"
EOF
  fi
}

ensure_codex_context_mode_hooks() {
  mkdir -p "$(dirname "$CODEX_HOOKS_PATH")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" node - "$CODEX_HOOKS_PATH" <<'NODE'
const { ensureHookCommand, ensureObject, loadJsonFile, saveJsonFile } = require(process.env.DEVCONTAINER_CONFIG_HELPERS);

const filePath = process.argv[2];
const config = loadJsonFile(filePath, { hooks: {} });
ensureObject(config, 'hooks');

ensureHookCommand(
  config,
  'PreToolUse',
  {
    matcher: 'local_shell|shell|shell_command|exec_command|Bash|Shell|apply_patch|Edit|Write|grep_files|ctx_execute|ctx_execute_file|ctx_batch_execute|ctx_fetch_and_index|ctx_search|ctx_index|mcp__',
    hooks: [{ type: 'command', command: 'context-mode hook codex pretooluse' }],
  },
  'context-mode hook codex pretooluse'
);
ensureHookCommand(
  config,
  'PostToolUse',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex posttooluse' }],
  },
  'context-mode hook codex posttooluse'
);
ensureHookCommand(
  config,
  'SessionStart',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex sessionstart' }],
  },
  'context-mode hook codex sessionstart'
);
ensureHookCommand(
  config,
  'PreCompact',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex precompact' }],
  },
  'context-mode hook codex precompact'
);
ensureHookCommand(
  config,
  'UserPromptSubmit',
  {
    hooks: [{ type: 'command', command: 'context-mode hook codex userpromptsubmit' }],
  },
  'context-mode hook codex userpromptsubmit'
);
ensureHookCommand(
  config,
  'Stop',
  {
    hooks: [{ type: 'command', command: 'context-mode hook codex stop' }],
  },
  'context-mode hook codex stop'
);

saveJsonFile(filePath, config);
NODE
}

ensure_codex_gitnexus_config() {
  local gitnexus_bin

  mkdir -p "$(dirname "$CODEX_CONFIG_PATH")"

  if [[ -f "$CODEX_CONFIG_PATH" ]] && grep -Fq '[mcp_servers.gitnexus]' "$CODEX_CONFIG_PATH"; then
    return
  fi

  gitnexus_bin="$(gitnexus_bin_path)"

  if [[ -n "$gitnexus_bin" ]]; then
    cat >>"$CODEX_CONFIG_PATH" <<EOF

[mcp_servers.gitnexus]
command = "$gitnexus_bin"
args = ["mcp"]
EOF
    return
  fi

  cat >>"$CODEX_CONFIG_PATH" <<'EOF'

[mcp_servers.gitnexus]
command = "npx"
args = ["-y", "gitnexus@latest", "mcp"]
EOF
}

ensure_opencode_context_mode_plugin() {
  local config_path
  local gitnexus_bin

  config_path="$(opencode_config_path)"
  gitnexus_bin="$(gitnexus_bin_path)"
  mkdir -p "$(dirname "$config_path")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" DEVCONTAINER_GITNEXUS_BIN="$gitnexus_bin" node - "$config_path" <<'NODE'
const { addUniqueValue, ensureArray, ensureObject, loadJsonFile, saveJsonFile } = require(process.env.DEVCONTAINER_CONFIG_HELPERS);

const filePath = process.argv[2];
const config = loadJsonFile(filePath, {}, { allowComments: true });
const gitnexusBin = process.env.DEVCONTAINER_GITNEXUS_BIN;

if (!config.$schema) {
  config.$schema = 'https://opencode.ai/config.json';
}

const plugins = ensureArray(config, 'plugin');
addUniqueValue(plugins, 'context-mode');

if (config.mcp && Object.prototype.hasOwnProperty.call(config.mcp, 'context-mode')) {
  delete config.mcp['context-mode'];
  if (Object.keys(config.mcp).length === 0) {
    delete config.mcp;
  }
}

const mcp = ensureObject(config, 'mcp');
mcp.gitnexus = gitnexusBin
  ? { type: 'local', command: [gitnexusBin, 'mcp'] }
  : { type: 'local', command: ['npx', '-y', 'gitnexus@latest', 'mcp'] };

saveJsonFile(filePath, config);
NODE
}

ensure_copilot_context_mode_mcp() {
  if ! command -v copilot >/dev/null 2>&1; then
    return
  fi

  if ! copilot mcp list 2>/dev/null | grep -Fq 'context-mode'; then
    copilot mcp add context-mode -- context-mode >/dev/null
  fi
}

ensure_copilot_gitnexus_mcp() {
  local gitnexus_bin

  if ! command -v copilot >/dev/null 2>&1; then
    return
  fi

  if copilot mcp list 2>/dev/null | grep -Fq 'gitnexus'; then
    return
  fi

  gitnexus_bin="$(gitnexus_bin_path)"

  if [[ -n "$gitnexus_bin" ]]; then
    copilot mcp add gitnexus -- "$gitnexus_bin" mcp >/dev/null
    return
  fi

  copilot mcp add gitnexus -- npx -y gitnexus@latest mcp >/dev/null
}

ensure_copilot_context_mode_hooks() {
  mkdir -p "$(dirname "$COPILOT_HOOKS_PATH")"

  cat >"$COPILOT_HOOKS_PATH" <<'EOF'
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli pretooluse"
      }
    ],
    "postToolUse": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli posttooluse"
      }
    ],
    "preCompact": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli precompact"
      }
    ],
    "sessionStart": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli sessionstart"
      }
    ],
    "userPromptSubmitted": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli userpromptsubmit"
      }
    ],
    "agentStop": [
      {
        "type": "command",
        "command": "context-mode hook copilot-cli stop"
      }
    ]
  }
}
EOF
}

main() {
  ensure_persistent_home_ownership
  ensure_pnpm_user_config
  ensure_codex_context_mode_config
  ensure_codex_context_mode_hooks
  ensure_codex_gitnexus_config
  ensure_opencode_context_mode_plugin
  ensure_copilot_context_mode_mcp
  ensure_copilot_gitnexus_mcp
  ensure_copilot_context_mode_hooks
  bash "$DEVCONTAINER_DIR/sanitize-git-config.sh"
}

main "$@"