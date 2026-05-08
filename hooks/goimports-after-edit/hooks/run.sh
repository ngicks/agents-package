#!/usr/bin/env bash
set -euo pipefail

test -f go.mod || exit 0
command -v goimports >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')

if [ "$event" = "Stop" ]; then
	goimports -w .
	exit 0
fi

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

goimports -w "$file"
