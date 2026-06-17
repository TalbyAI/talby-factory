#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# post-create.sh
# Installs pinned CLI dependencies for the talby-factory DevContainer.

set -euo pipefail

readonly ASPIRE_VERSION="13.4.5"
readonly COPILOT_VERSION="1.0.63"
readonly OPENCODE_VERSION="1.17.7"
readonly CODEX_VERSION="0.140.0"
readonly CONTEXT_MODE_VERSION="1.0.162"
readonly SKILLS_VERSION="1.5.11"
readonly SKILLS_TARGET_AGENTS=("codex" "github-copilot" "opencode")
readonly CODEX_CONFIG_PATH="/home/vscode/.codex/config.toml"
readonly CODEX_HOOKS_PATH="/home/vscode/.codex/hooks.json"
readonly OPENCODE_CONFIG_PATH="/home/vscode/.config/opencode/opencode.jsonc"
readonly CLAUDE_SETTINGS_PATH="/home/vscode/.claude/settings.json"
readonly VSCODE_REMOTE_MCP_PATH="/home/vscode/.vscode-server/data/Machine/mcp.json"

ensure_directory() {
  local path="$1"

  mkdir -p "$path"
}

run_skills_global_command() {
  local temp_dir

  temp_dir="$(mktemp -d)"

  (
    cd "$temp_dir"
    skills "$@"
  )

  rm -rf "$temp_dir"
}

install_global_skills() {
  run_skills_global_command add mattpocock/skills --global --yes \
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

  node - "$CODEX_HOOKS_PATH" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];

const ensureEventGroup = (config, eventName, group, command) => {
  const entries = Array.isArray(config.hooks[eventName]) ? config.hooks[eventName] : [];
  const alreadyPresent = entries.some((entry) =>
    Array.isArray(entry.hooks) && entry.hooks.some((hook) => hook.type === 'command' && hook.command === command)
  );

  if (!alreadyPresent) {
    entries.push(group);
  }

  config.hooks[eventName] = entries;
};

let config = { hooks: {} };

if (fs.existsSync(filePath)) {
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (raw) {
    config = JSON.parse(raw);
  }
}

if (!config.hooks || typeof config.hooks !== 'object') {
  config.hooks = {};
}

ensureEventGroup(
  config,
  'PreToolUse',
  {
    matcher: 'local_shell|shell|shell_command|exec_command|Bash|Shell|apply_patch|Edit|Write|grep_files|ctx_execute|ctx_execute_file|ctx_batch_execute|ctx_fetch_and_index|ctx_search|ctx_index|mcp__',
    hooks: [{ type: 'command', command: 'context-mode hook codex pretooluse' }],
  },
  'context-mode hook codex pretooluse'
);
ensureEventGroup(
  config,
  'PostToolUse',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex posttooluse' }],
  },
  'context-mode hook codex posttooluse'
);
ensureEventGroup(
  config,
  'SessionStart',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex sessionstart' }],
  },
  'context-mode hook codex sessionstart'
);
ensureEventGroup(
  config,
  'PreCompact',
  {
    matcher: '',
    hooks: [{ type: 'command', command: 'context-mode hook codex precompact' }],
  },
  'context-mode hook codex precompact'
);
ensureEventGroup(
  config,
  'UserPromptSubmit',
  {
    hooks: [{ type: 'command', command: 'context-mode hook codex userpromptsubmit' }],
  },
  'context-mode hook codex userpromptsubmit'
);
ensureEventGroup(
  config,
  'Stop',
  {
    hooks: [{ type: 'command', command: 'context-mode hook codex stop' }],
  },
  'context-mode hook codex stop'
);

fs.writeFileSync(filePath, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

ensure_opencode_context_mode_plugin() {
  ensure_directory "$(dirname "$OPENCODE_CONFIG_PATH")"

  node - "$OPENCODE_CONFIG_PATH" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];

const stripJsonComments = (input) => {
  let output = '';
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let index = 0; index < input.length; index += 1) {
    const current = input[index];
    const next = input[index + 1];

    if (inLineComment) {
      if (current === '\n') {
        inLineComment = false;
        output += current;
      }
      continue;
    }

    if (inBlockComment) {
      if (current === '*' && next === '/') {
        inBlockComment = false;
        index += 1;
      }
      continue;
    }

    if (inString) {
      output += current;
      if (escaped) {
        escaped = false;
      } else if (current === '\\') {
        escaped = true;
      } else if (current === '"') {
        inString = false;
      }
      continue;
    }

    if (current === '"') {
      inString = true;
      output += current;
      continue;
    }

    if (current === '/' && next === '/') {
      inLineComment = true;
      index += 1;
      continue;
    }

    if (current === '/' && next === '*') {
      inBlockComment = true;
      index += 1;
      continue;
    }

    output += current;
  }

  return output;
};

let config = {};

if (fs.existsSync(filePath)) {
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (raw) {
    config = JSON.parse(stripJsonComments(raw));
  }
}

if (!config.$schema) {
  config.$schema = 'https://opencode.ai/config.json';
}

if (!Array.isArray(config.plugin)) {
  config.plugin = [];
}

if (!config.plugin.includes('context-mode')) {
  config.plugin.push('context-mode');
}

if (config.mcp && Object.prototype.hasOwnProperty.call(config.mcp, 'context-mode')) {
  delete config.mcp['context-mode'];
  if (Object.keys(config.mcp).length === 0) {
    delete config.mcp;
  }
}

fs.writeFileSync(filePath, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

ensure_vscode_context_mode_mcp() {
  ensure_directory "$(dirname "$VSCODE_REMOTE_MCP_PATH")"

  node - "$VSCODE_REMOTE_MCP_PATH" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];

let config = { servers: {} };

if (fs.existsSync(filePath)) {
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (raw) {
    config = JSON.parse(raw);
  }
}

if (!config.servers || typeof config.servers !== 'object') {
  config.servers = {};
}

config.servers['context-mode'] = {
  command: 'context-mode',
};

fs.writeFileSync(filePath, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

ensure_vscode_context_mode_hooks() {
  ensure_directory "$(dirname "$CLAUDE_SETTINGS_PATH")"

  node - "$CLAUDE_SETTINGS_PATH" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];

const ensureEventGroup = (config, eventName, group, command) => {
  const entries = Array.isArray(config.hooks[eventName]) ? config.hooks[eventName] : [];
  const alreadyPresent = entries.some((entry) =>
    Array.isArray(entry.hooks) && entry.hooks.some((hook) => hook.type === 'command' && hook.command === command)
  );

  if (!alreadyPresent) {
    entries.push(group);
  }

  config.hooks[eventName] = entries;
};

let config = {};

if (fs.existsSync(filePath)) {
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (raw) {
    config = JSON.parse(raw);
  }
}

if (!config.hooks || typeof config.hooks !== 'object') {
  config.hooks = {};
}

ensureEventGroup(
  config,
  'PreToolUse',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot pretooluse' }],
  },
  'context-mode hook vscode-copilot pretooluse'
);
ensureEventGroup(
  config,
  'PostToolUse',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot posttooluse' }],
  },
  'context-mode hook vscode-copilot posttooluse'
);
ensureEventGroup(
  config,
  'PreCompact',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot precompact' }],
  },
  'context-mode hook vscode-copilot precompact'
);
ensureEventGroup(
  config,
  'SessionStart',
  {
    hooks: [{ type: 'command', command: 'context-mode hook vscode-copilot sessionstart' }],
  },
  'context-mode hook vscode-copilot sessionstart'
);

fs.writeFileSync(filePath, `${JSON.stringify(config, null, 2)}\n`);
NODE
}

main() {
  dotnet tool update --global aspire.cli --version "$ASPIRE_VERSION" \
    || dotnet tool install --global aspire.cli --version "$ASPIRE_VERSION"

  npm install -g \
    "@github/copilot@$COPILOT_VERSION" \
    "opencode-ai@$OPENCODE_VERSION" \
    "@openai/codex@$CODEX_VERSION" \
    "context-mode@$CONTEXT_MODE_VERSION" \
    "skills@$SKILLS_VERSION"

  install_global_skills

  ensure_codex_context_mode_config
  ensure_codex_context_mode_hooks
  ensure_opencode_context_mode_plugin
  ensure_vscode_context_mode_mcp
  ensure_vscode_context_mode_hooks

  docker --version
  node --version
  pnpm --version
  aspire --version || aspire version
  copilot --version
  opencode --version
  codex --version
  context-mode doctor
  test -f "$CODEX_CONFIG_PATH"
  test -f "$CODEX_HOOKS_PATH"
  test -f "$OPENCODE_CONFIG_PATH"
  test -f "$VSCODE_REMOTE_MCP_PATH"
  test -f "$CLAUDE_SETTINGS_PATH"
  skills --version
  run_skills_global_command ls --global --json >/dev/null
}

main "$@"
