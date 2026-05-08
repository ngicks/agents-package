#!/usr/bin/env bash
set -euo pipefail

test -f go.mod || exit 0
command -v golangci-lint >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')

if [ "$event" = "Stop" ]; then
	if [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ]; then
		exit 0
	fi
	if ! output=$(golangci-lint run ./... 2>&1); then
		printf '%s\n' "$output" >&2
		exit 2
	fi
	exit 0
fi

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

case "$file" in
*.go) ;;
*) exit 0 ;;
esac

if ! output=$(golangci-lint run "$(dirname -- "$file")" 2>&1); then
	printf '%s\n' "$output" >&2
	exit 2
fi
