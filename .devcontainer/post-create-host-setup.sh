#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# post-create-host-setup.sh
# Applies the second automatic post-create phase for user-level agent personalization.

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OPENSRC_SKILL_SOURCE="vercel-labs/opensrc/skills/opensrc#v0.7.2"

source "$DEVCONTAINER_DIR/lib.sh"

readonly SKILLS_TARGET_AGENTS=("codex" "github-copilot" "opencode")
readonly CODEX_CONFIG_PATH="/home/vscode/.codex/config.toml"
readonly CODEX_HOOKS_PATH="/home/vscode/.codex/hooks.json"
readonly OPENCODE_CONFIG_PATH="/home/vscode/.config/opencode/opencode.jsonc"
readonly CLAUDE_SETTINGS_PATH="/home/vscode/.claude/settings.json"
readonly VSCODE_REMOTE_MCP_PATH="/home/vscode/.vscode-server/data/Machine/mcp.json"
readonly CONFIG_HELPERS_PATH="$DEVCONTAINER_DIR/config-helpers.js"

run_skills_global_command() {
  local temp_dir

  temp_dir="$(mktemp -d)"
  trap 'cleanup_path "$temp_dir"' RETURN

  (
    cd "$temp_dir"
    skills "$@"
  )
}

install_global_skills() {
  run_skills_global_command add mattpocock/skills --global --yes \
    --agent "${SKILLS_TARGET_AGENTS[@]}"
  run_skills_global_command add "$OPENSRC_SKILL_SOURCE" --global --yes \
    --agent "${SKILLS_TARGET_AGENTS[@]}"
}

ensure_codex_context_mode_config() {
  local temp_file

  ensure_directory "$(dirname "$CODEX_CONFIG_PATH")"

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
  ensure_directory "$(dirname "$CODEX_HOOKS_PATH")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" node - "$CODEX_HOOKS_PATH" <<'NODE'
const fs = require('fs');
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

ensure_opencode_context_mode_plugin() {
  ensure_directory "$(dirname "$OPENCODE_CONFIG_PATH")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" node - "$OPENCODE_CONFIG_PATH" <<'NODE'
const { addUniqueValue, ensureArray, loadJsonFile, saveJsonFile } = require(process.env.DEVCONTAINER_CONFIG_HELPERS);

const filePath = process.argv[2];
const config = loadJsonFile(filePath, {}, { allowComments: true });

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

saveJsonFile(filePath, config);
NODE
}

ensure_vscode_context_mode_mcp() {
  ensure_directory "$(dirname "$VSCODE_REMOTE_MCP_PATH")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" node - "$VSCODE_REMOTE_MCP_PATH" <<'NODE'
const { ensureObject, loadJsonFile, saveJsonFile } = require(process.env.DEVCONTAINER_CONFIG_HELPERS);

const filePath = process.argv[2];

const config = loadJsonFile(filePath, { servers: {} });
const servers = ensureObject(config, 'servers');

servers['context-mode'] = {
  command: 'context-mode',
};

saveJsonFile(filePath, config);
NODE
}

ensure_vscode_context_mode_hooks() {
  ensure_directory "$(dirname "$CLAUDE_SETTINGS_PATH")"

  DEVCONTAINER_CONFIG_HELPERS="$CONFIG_HELPERS_PATH" node - "$CLAUDE_SETTINGS_PATH" <<'NODE'
const { ensureHookCommand, ensureObject, loadJsonFile, saveJsonFile } = require(process.env.DEVCONTAINER_CONFIG_HELPERS);

const filePath = process.argv[2];
const config = loadJsonFile(filePath, { hooks: {} });
ensureObject(config, 'hooks');

ensureHookCommand(
  config,
  'PreToolUse',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot pretooluse' }],
  },
  'context-mode hook vscode-copilot pretooluse'
);
ensureHookCommand(
  config,
  'PostToolUse',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot posttooluse' }],
  },
  'context-mode hook vscode-copilot posttooluse'
);
ensureHookCommand(
  config,
  'PreCompact',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot precompact' }],
  },
  'context-mode hook vscode-copilot precompact'
);
ensureHookCommand(
  config,
  'SessionStart',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot sessionstart' }],
  },
  'context-mode hook vscode-copilot sessionstart'
);

saveJsonFile(filePath, config);
NODE
}

verify_host_setup() {
  test -f "$CODEX_CONFIG_PATH"
  test -f "$CODEX_HOOKS_PATH"
  test -f "$OPENCODE_CONFIG_PATH"
  test -f "$VSCODE_REMOTE_MCP_PATH"
  test -f "$CLAUDE_SETTINGS_PATH"
  run_skills_global_command ls --global --json | grep -F 'opensrc' >/dev/null
  context-mode doctor
}

print_host_setup_summary() {
  cat <<'EOF'

Optional host-level agent setup finished.
Global skills and Context Mode host wiring are now configured for the current user.
EOF
}

main() {
  install_global_skills

  ensure_codex_context_mode_config
  ensure_codex_context_mode_hooks
  ensure_opencode_context_mode_plugin
  ensure_vscode_context_mode_mcp
  ensure_vscode_context_mode_hooks

  verify_host_setup
  print_host_setup_summary
}

main "$@"