#!/usr/bin/env bash
set -euo pipefail

test -f go.mod || exit 0
command -v golangci-lint >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')

if [ "$event" = "Stop" ]; then
	golangci-lint fmt ./...
	exit 0
fi

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

golangci-lint fmt "$file"
