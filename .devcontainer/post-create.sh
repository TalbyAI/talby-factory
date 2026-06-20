#!/usr/bin/env bash

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
  bash "$DEVCONTAINER_DIR/sanitize-git-config.sh"
}

main "$@"