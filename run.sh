#!/usr/bin/env bash
# Runs Claude Code in the container. Arguments are passed to claude.
set -euo pipefail

script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$script_dir/common.sh"

docker run "${run_args[@]}" "$image" "$@"
