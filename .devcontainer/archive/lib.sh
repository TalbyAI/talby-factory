#!/usr/bin/env bash

ensure_directory() {
  local path="$1"

  mkdir -p "$path"
}

cleanup_path() {
  local path="${1:-}"

  if [[ -n "$path" ]]; then
    rm -rf "$path"
  fi
}