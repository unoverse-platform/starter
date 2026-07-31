#!/usr/bin/env bash
# Find project root and set global paths

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"

find_root() {
  # First: check current working directory (for global installs)
  if [ -f "$PWD/docker-compose.yml" ]; then
    echo "$PWD"
    return
  fi

  # Second: check relative to script location (for unoverse usage)
  local dir="$SCRIPT_DIR"
  if [ "$(basename "$dir")" = "scripts" ]; then
    dir="$(dirname "$dir")"
  fi
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "$dir"
    return
  fi

  echo "Error: No docker-compose.yml found in current directory" >&2
  echo "  Run this command from your Unoverse project folder." >&2
  exit 1
}

ROOT="$(find_root)"
