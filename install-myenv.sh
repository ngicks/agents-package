#!/usr/bin/env bash

set -euo pipefail

sources=(ngicks/agents-package/bundle/myenv)
targets="claude,codex,opencode"

if ! command -v apm >/dev/null 2>&1; then
  echo "apm not found; install it first, e.g. 'mise use -g pipx:apm-cli' or 'pipx install apm-cli'" >&2
  exit 1
fi

# The bundle lists mods that ship bin/ executables and transitive packages
# that define their own MCP servers. apm skips both in non-interactive
# shells unless told to trust them.
apm install -g -t "$targets" --trust-bin --trust-transitive-mcp "${sources[@]}"

# apm writes the crabswarm-mcp-shared MCP server into ~/.claude.json too.
# Claude Code does not need it. The claude CLI offers no disable, only
# remove, and remove exits 1 when the entry is already gone.
if command -v claude >/dev/null 2>&1; then
  claude mcp remove crabswarm-mcp-shared --scope user || true
fi

if [ "${MYENV_UPDATE:-0}" = "1" ]; then
  apm update -g --yes
fi
