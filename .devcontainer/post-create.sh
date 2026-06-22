#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PNPM_BIN_DIR="/usr/local/share/pnpm/bin"
readonly PNPM_GLOBAL_DIR="/usr/local/share/pnpm-global"
readonly PNPM_CONFIG_DIR="/home/vscode/.config/pnpm"
readonly PNPM_CONFIG_FILE="$PNPM_CONFIG_DIR/config.yaml"
readonly PERSISTENT_HOME_DIRS=(
  "/home/vscode/.codex"
  "/home/vscode/.config/opencode"
  "/home/vscode/.local/share/opencode"
  "/home/vscode/.local/state/opencode"
  "/home/vscode/.opensrc"
  "/home/vscode/.agents/skills"
)

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

main() {
  ensure_persistent_home_ownership
  ensure_pnpm_user_config
  bash "$DEVCONTAINER_DIR/sanitize-git-config.sh"
}

main "$@"