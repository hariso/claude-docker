#!/usr/bin/env bash
# Opens a bash shell in the container instead of Claude Code. Arguments are passed to bash.
set -euo pipefail

script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$script_dir/common.sh"

exec docker run "${run_args[@]}" --entrypoint bash "$image" "$@"
