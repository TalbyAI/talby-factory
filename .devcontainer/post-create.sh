#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PERSISTENT_HOME_DIRS=(
  "/home/vscode/.codex"
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

main() {
  ensure_persistent_home_ownership
  bash "$DEVCONTAINER_DIR/sanitize-git-config.sh"
}

main "$@"