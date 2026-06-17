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
readonly SKILLS_VERSION="1.5.11"

main() {
  dotnet tool update --global aspire.cli --version "$ASPIRE_VERSION" \
    || dotnet tool install --global aspire.cli --version "$ASPIRE_VERSION"

  npm install -g \
    "@github/copilot@$COPILOT_VERSION" \
    "opencode-ai@$OPENCODE_VERSION" \
    "@openai/codex@$CODEX_VERSION" \
    "skills@$SKILLS_VERSION"

  skills add mattpocock/skills --global --yes

  docker --version
  node --version
  pnpm --version
  aspire --version || aspire version
  copilot --version
  opencode --version
  codex --version
  skills --version
  skills ls --global --json >/dev/null
}

main "$@"
