#!/usr/bin/env bash

set -euo pipefail

main() {
  local gitconfig_path
  local removed=0
  local temp_file

  gitconfig_path="${HOME}/.gitconfig"

  if [[ ! -f "$gitconfig_path" ]]; then
    exit 0
  fi

  temp_file="$(mktemp)"

  awk '
    /^\[safe\]\r?$/ {
      in_safe = 1
      safe_block = $0 ORS
      next
    }

    /^\[.*\]\r?$/ {
      if (in_safe) {
        printf "%s", safe_block
        safe_block = ""
        in_safe = 0
      }

      print
      next
    }

    {
      if (!in_safe) {
        print
        next
      }

      if ($0 ~ /^[[:space:]]*directory = [A-Za-z]:\//) {
        removed = 1
        next
      }

      safe_block = safe_block $0 ORS
    }

    END {
      if (in_safe) {
        printf "%s", safe_block
      }

      if (removed) {
        exit 10
      }
    }
  ' "$gitconfig_path" > "$temp_file" || status=$?

  status="${status:-0}"

  if [[ "$status" -ne 0 && "$status" -ne 10 ]]; then
    rm -f "$temp_file"
    exit "$status"
  fi

  if [[ "$status" -eq 10 ]]; then
    mv "$temp_file" "$gitconfig_path"
    removed=1
  else
    rm -f "$temp_file"
  fi

  if [[ "$removed" -eq 1 ]]; then
    echo "Removed non-portable safe.directory entries from global Git config."
  fi
}

main "$@"