#!/usr/bin/env bash
# Builds the Claude Code image for the current host user.
set -euo pipefail

script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
version=$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$script_dir/Dockerfile")

exec docker build -t "claude-code:$version" \
  --build-arg USER_NAME="$(id -un)" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  "$script_dir"
