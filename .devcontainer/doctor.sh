#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# doctor.sh
# Validates Dev Container tooling, user wiring, Git identity, and auth hints.

set -euo pipefail

ok() {
  printf 'OK: %s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
}

check_command() {
  local description="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    ok "$description"
    return 0
  fi

  fail "$description"
  return 1
}

check_file() {
  local path="$1"

  if [[ -f "$path" ]]; then
    ok "Found $path"
    return 0
  fi

  fail "Missing $path"
  return 1
}

check_git_value() {
  local key="$1"
  local value

  value="$(git config --get "$key" || true)"

  if [[ -n "$value" ]]; then
    ok "Git config $key is set"
    return 0
  fi

  fail "Git config $key is missing"
  return 1
}

check_warning_command() {
  local success_description="$1"
  local warning_description="$2"
  local remediation="$3"
  shift 3

  if "$@" >/dev/null 2>&1; then
    ok "$success_description"
    return 0
  fi

  warn "$warning_description"
  printf '  Run: %s\n' "$remediation"
  return 0
}

main() {
  local failures=0

  printf 'Running Dev Container doctor...\n'

  check_command 'docker is available' docker --version || failures=1
  check_command 'node is available' node --version || failures=1
  check_command 'pnpm is available' pnpm --version || failures=1
  check_command 'aspire is available' aspire --version || aspire version || failures=1
  check_command 'copilot is available' copilot --version || failures=1
  check_command 'opencode is available' opencode --version || failures=1
  check_command 'codex is available' codex --version || failures=1
  check_command 'context-mode doctor passes' context-mode doctor || failures=1
  check_command 'gitnexus is available' gitnexus --version || failures=1
  check_command 'gitnexus doctor passes' gitnexus doctor || failures=1
  check_command 'gh is available' gh --version || failures=1
  check_command 'gentle-ai is available' gentle-ai version || failures=1
  check_command 'engram is available' engram version || failures=1
  check_command 'gga is available' gga version || failures=1
  check_command 'markdownlint-cli2 is available' markdownlint-cli2 --version || failures=1
  check_command 'csharpier is available' csharpier --version || failures=1
  check_command 'biome is available' biome --version || failures=1
  check_command 'opensrc is available' opensrc --version || failures=1
  check_command 'skills is available' skills --version || failures=1
  check_command 'just is available' just --version || failures=1

  check_file "$HOME/.agents/.skill-lock.json" || failures=1
  check_file "$HOME/.codex/config.toml" || failures=1
  check_file "$HOME/.codex/hooks.json" || failures=1
  check_file "$HOME/.config/opencode/opencode.jsonc" || failures=1
  check_file "$HOME/.vscode-server/data/Machine/mcp.json" || failures=1
  check_file "$HOME/.claude/settings.json" || failures=1

  check_git_value 'user.name' || failures=1
  check_git_value 'user.email' || failures=1
  check_git_value 'gpg.format' || failures=1
  check_git_value 'user.signingkey' || failures=1

  check_warning_command \
    'GitHub CLI is authenticated' \
    'GitHub CLI is not authenticated' \
    'gh auth login' \
    gh auth status

  check_warning_command \
    'Codex is authenticated' \
    'Codex is not authenticated' \
    'codex login' \
    codex login status

  check_warning_command \
    'OpenCode has provider credentials configured' \
    'OpenCode has no provider credentials configured' \
    'opencode providers' \
    opencode providers list

  if [[ -n "${COPILOT_GITHUB_TOKEN:-}" || -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
    ok 'Copilot CLI has an auth token available via environment'
  else
    warn 'Copilot CLI has no obvious auth token in environment'
    printf '  Run: copilot login\n'
  fi

  if [[ "$failures" -ne 0 ]]; then
    fail 'Doctor found one or more hard failures.'
    return 1
  fi

  ok 'Doctor completed without hard failures.'
}

main "$@"