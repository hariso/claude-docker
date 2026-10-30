# Sourced by run.sh and run-shell.sh. Expects script_dir; sets image and run_args for docker run.

image=claude-code:$(sed -n 's/^ARG CLAUDE_CODE_VERSION=//p' "$script_dir/Dockerfile")

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

run_args=(
  --rm -it
  --network host
  -e TERM -e COLORTERM
  -w "$PWD"
  "${mounts[@]}"
)
