# Sourced by run.sh and run-shell.sh. Expects script_dir; sets image and run_args for docker run.
# Starts a relay sidecar that an EXIT trap stops, so callers must not exec docker run.

image=claude-code:$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$script_dir/Dockerfile")

# Host-loopback ports the container may reach, e.g. the IntelliJ MCP server.
relay_ports=(64342)

mounts=(
  -v "$HOME/.claude:$HOME/.claude"
  -v "$HOME/.claude.json:$HOME/.claude.json"
  -v "$HOME/.gitconfig:$HOME/.gitconfig:ro"
  -v "claude-m2:$HOME/.m2"
  -v "claude-jdtls-cache:$HOME/.cache/jdtls"
)

dirs=()
while IFS= read -r dir; do
  dirs+=("${dir%/}")
done < <(jq -r '.permissions.additionalDirectories[]?' "$HOME/.claude/settings.json")

declare -A seen
inside=
for dir in "${dirs[@]}"; do
  case "$dir" in
    "$HOME/.m2" | "$HOME/.m2/"*) continue ;;
  esac
  [[ -n "${seen[$dir]:-}" ]] && continue
  seen[$dir]=1
  # docker creates missing bind sources as root-owned directories on the host
  if [[ ! -d "$dir" ]]; then
    echo "skipping missing directory: $dir" >&2
    continue
  fi
  mounts+=(-v "$dir:$dir")
  if [[ "$PWD" == "$dir" || "$PWD" == "$dir/"* ]]; then
    inside=1
  fi
done

if [[ -z "$inside" ]]; then
  echo "not inside an additionalDirectories entry: $PWD" >&2
  exit 1
fi

docker network inspect claude >/dev/null 2>&1 || docker network create claude >/dev/null

relay_dir=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/claude-relay.XXXXXX")
relay_name=claude-relay-$$
trap 'docker stop "$relay_name" >/dev/null 2>&1; rm -rf "$relay_dir"' EXIT
docker run -d --rm --init --network host --name "$relay_name" \
  --user "$(id -u):$(id -g)" \
  -v "$relay_dir:/run/claude-relay" \
  --entrypoint /usr/local/bin/relay.sh \
  "$image" "${relay_ports[@]}" >/dev/null
mounts+=(-v "$relay_dir:/run/claude-relay")

run_args=(
  --rm -it --init
  --network claude
  --cap-add NET_ADMIN
  --security-opt no-new-privileges
  -e TERM -e COLORTERM -e GH_TOKEN
  -e "RELAY_PORTS=${relay_ports[*]}"
  -e "HOST_ADDRS=$(hostname -I)"
  -w "$PWD"
  "${mounts[@]}"
)
