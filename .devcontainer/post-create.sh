#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# post-create.sh
# Installs pinned CLI dependencies for the talby-factory DevContainer.

set -euo pipefail

readonly DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DEVCONTAINER_DIR/lib.sh"

readonly ASPIRE_VERSION="13.4.5"
readonly COPILOT_VERSION="1.0.63"
readonly OPENCODE_VERSION="1.17.7"
readonly CODEX_VERSION="0.140.0"
readonly CONTEXT_MODE_VERSION="1.0.162"
readonly GITNEXUS_VERSION="1.6.7"
readonly GH_VERSION="2.95.0"
readonly MARKDOWNLINT_CLI2_VERSION="0.22.1"
readonly CSHARPIER_VERSION="1.3.0"
readonly BIOME_VERSION="2.5.0"
readonly SKILLS_VERSION="1.5.11"
readonly GH_INSTALL_ROOT="/usr/local/lib/gh-cli"
readonly HOST_GITCONFIG_PATH="/home/vscode/.gitconfig-host"
readonly SANITIZED_HOST_GITCONFIG_PATH="/home/vscode/.config/git/host-identity.inc"
readonly ALLOWED_SIGNERS_PATH="/home/vscode/.config/git/allowed_signers"

select_ssh_signing_key() {
  ssh-add -L 2>/dev/null | awk '
    /ssh-ed25519/ {
      found = 1
      print
      exit
    }

    NR == 1 {
      first = $0
    }

    END {
      if (found != 1 && NR > 0 && first != "") {
        print first
      }
    }
  '
}

write_allowed_signers_file() {
  local principal="$1"
  local public_key="$2"

  ensure_directory "$(dirname "$ALLOWED_SIGNERS_PATH")"
  printf '%s %s\n' "$principal" "$public_key" >"$ALLOWED_SIGNERS_PATH"
}

write_sanitized_git_host_config() {
  local agent_public_key
  local commit_gpgsign
  local gpg_format
  local skipped_signing_settings=0
  local tag_gpgsign
  local temp_file
  local user_email
  local user_name
  local user_signing_key
  local allowed_signers_file
  local signing_key_source="host"

  ensure_directory "$(dirname "$SANITIZED_HOST_GITCONFIG_PATH")"

  temp_file="$(mktemp)"

  user_name="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get user.name || true)"
  user_email="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get user.email || true)"
  user_signing_key="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get user.signingKey || true)"
  gpg_format="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get gpg.format || true)"
  commit_gpgsign="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get commit.gpgsign || true)"
  tag_gpgsign="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get tag.gpgsign || true)"
  allowed_signers_file="$(git config --file "$HOST_GITCONFIG_PATH" --includes --get gpg.ssh.allowedSignersFile || true)"

  if [[ -n "$gpg_format" && "$gpg_format" != "ssh" ]]; then
    skipped_signing_settings=1

    agent_public_key="$(select_ssh_signing_key || true)"

    if [[ -n "$agent_public_key" ]]; then
      gpg_format="ssh"
      user_signing_key="$agent_public_key"
      signing_key_source="agent"

      if [[ -z "$commit_gpgsign" ]]; then
        commit_gpgsign="true"
      fi

      if [[ -z "$tag_gpgsign" ]]; then
        tag_gpgsign="true"
      fi

      if [[ -z "$allowed_signers_file" && -n "$user_email" ]]; then
        write_allowed_signers_file "$user_email" "$agent_public_key"
        allowed_signers_file="$ALLOWED_SIGNERS_PATH"
      fi
    fi
  fi

  {
    if [[ -n "$user_name" || -n "$user_email" || ( "$gpg_format" == "ssh" && -n "$user_signing_key" ) ]]; then
      echo "[user]"

      if [[ -n "$user_name" ]]; then
        printf '\tname = %s\n' "$user_name"
      fi

      if [[ -n "$user_email" ]]; then
        printf '\temail = %s\n' "$user_email"
      fi

      if [[ "$gpg_format" == "ssh" && -n "$user_signing_key" ]]; then
        printf '\tsigningKey = %s\n' "$user_signing_key"
      fi
    fi

    if [[ "$gpg_format" == "ssh" && -n "$user_signing_key" ]]; then
      echo
      echo "[gpg]"
      printf '\tformat = %s\n' "$gpg_format"

      if [[ -n "$commit_gpgsign" ]]; then
        echo
        echo "[commit]"
        printf '\tgpgsign = %s\n' "$commit_gpgsign"
      fi

      if [[ -n "$tag_gpgsign" ]]; then
        echo
        echo "[tag]"
        printf '\tgpgSign = %s\n' "$tag_gpgsign"
      fi

      if [[ -n "$allowed_signers_file" ]]; then
        echo
        echo '[gpg "ssh"]'
        printf '\tallowedSignersFile = %s\n' "$allowed_signers_file"
      fi
    fi
  } >"$temp_file"

  mv "$temp_file" "$SANITIZED_HOST_GITCONFIG_PATH"

  if [[ "$skipped_signing_settings" -eq 1 ]]; then
    if [[ "$signing_key_source" == "agent" ]]; then
      echo "Replaced non-portable host signing settings with SSH signing from the forwarded agent."
    else
      echo "Skipping host signing settings because only SSH signing is portable inside the container."
    fi
  fi
}

remove_git_global_include_path() {
  local include_path="$1"

  while git config --global --get-all include.path | grep -Fxq "$include_path"; do
    git config --global --unset-all include.path "$include_path"
  done
}

ensure_git_host_config_include() {
  local include_paths

  if [[ ! -f "$HOST_GITCONFIG_PATH" ]]; then
    echo "Skipping host Git include because $HOST_GITCONFIG_PATH is not mounted."
    return
  fi

  write_sanitized_git_host_config
  remove_git_global_include_path "$HOST_GITCONFIG_PATH"

  include_paths="$(git config --global --get-all include.path || true)"

  if printf '%s\n' "$include_paths" | grep -Fxq "$SANITIZED_HOST_GITCONFIG_PATH"; then
    return
  fi

  git config --global --add include.path "$SANITIZED_HOST_GITCONFIG_PATH"
}

install_gh_cli() {
  local architecture
  local asset_name
  local download_url
  local temp_dir

  architecture="$(dpkg --print-architecture)"

  case "$architecture" in
    amd64 | arm64)
      ;;
    *)
      echo "Unsupported architecture for GitHub CLI: $architecture" >&2
      return 1
      ;;
  esac

  asset_name="gh_${GH_VERSION}_linux_${architecture}.tar.gz"
  download_url="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${asset_name}"
  temp_dir="$(mktemp -d)"
  trap 'cleanup_path "$temp_dir"' RETURN

  curl --fail --silent --show-error --location \
    --retry 5 \
    --retry-all-errors \
    --retry-delay 2 \
    "$download_url" -o "$temp_dir/$asset_name"
  sudo rm -rf "$GH_INSTALL_ROOT"
  sudo mkdir -p "$GH_INSTALL_ROOT"
  sudo tar -xzf "$temp_dir/$asset_name" \
    --strip-components=1 \
    -C "$GH_INSTALL_ROOT"
  sudo install -m 0755 "$GH_INSTALL_ROOT/bin/gh" /usr/local/bin/gh
}

install_dotnet_tools() {
  dotnet tool update --global aspire.cli --version "$ASPIRE_VERSION" \
    || dotnet tool install --global aspire.cli --version "$ASPIRE_VERSION"
  dotnet tool update --global csharpier --version "$CSHARPIER_VERSION" \
    || dotnet tool install --global csharpier --version "$CSHARPIER_VERSION"
}

install_node_tools() {
  npm install -g \
    "@github/copilot@$COPILOT_VERSION" \
    "opencode-ai@$OPENCODE_VERSION" \
    "@openai/codex@$CODEX_VERSION" \
    "context-mode@$CONTEXT_MODE_VERSION" \
    "gitnexus@$GITNEXUS_VERSION" \
    "markdownlint-cli2@$MARKDOWNLINT_CLI2_VERSION" \
    "@biomejs/biome@$BIOME_VERSION" \
    "skills@$SKILLS_VERSION"
}

verify_base_bootstrap() {
  docker --version
  node --version
  pnpm --version
  aspire --version || aspire version
  copilot --version
  opencode --version
  codex --version
  context-mode doctor
  gitnexus --version
  gitnexus doctor
  gh --version
  markdownlint-cli2 --version >/dev/null
  command -v csharpier >/dev/null
  csharpier --version
  biome --version
  skills --version
}

print_base_bootstrap_summary() {
  cat <<'EOF'

Base Dev Container bootstrap finished.
Host Git config include path:
  /home/vscode/.gitconfig-host
Optional host-level agent setup now lives in:
  bash .devcontainer/post-create-host-setup.sh
Run it manually after attach if you want global skills installation and Context Mode host wiring.
EOF
}

main() {
  ensure_git_host_config_include
  install_dotnet_tools
  install_gh_cli
  install_node_tools
  verify_base_bootstrap
  print_base_bootstrap_summary
}

main "$@"
