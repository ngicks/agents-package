#!/usr/bin/env bash

set -e

# Verbatim helper packages, as paths relative to helpers/. Each path is
# mirrored under <project-root>, so helpers/internal/loggerfactory/ lands at
# <project-root>/internal/loggerfactory/. Every *.go file in the package
# (source and _test.go alike) is copied.
ALWAYS_DIRS=(
  cmd/internal/cmdsignals
  internal/loggerfactory
  internal/versioninfo
  internal/cmd/release
)
# Copied only with --stdiopipe (a subcommand needs cancellable stdio).
STDIOPIPE_DIR=cmd/internal/stdiopipe

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HELPERS_DIR="$SCRIPT_DIR/helpers"

usage() {
  echo "Usage:"
  echo "  $0 <project-root> [--stdiopipe]"
  echo ""
  echo "Copies the go-edit-cobra verbatim helper packages (source and tests)"
  echo "into <project-root>, mirroring each package's path:"
  echo ""
  echo "  cmd/internal/cmdsignals/    always"
  echo "  internal/loggerfactory/     always"
  echo "  internal/versioninfo/       always"
  echo "  internal/cmd/release/       always"
  echo "  cmd/internal/stdiopipe/     only with --stdiopipe"
  echo ""
  echo "<project-root> must already exist (the module root containing go.mod)."
  exit 1
}

copy_dir() {
  local rel="$1"
  local src_dir="$HELPERS_DIR/$rel"
  local dst_dir="$DEST/$rel"

  if [[ ! -d "$src_dir" ]]; then
    echo "Error: helper source not found: $src_dir" >&2
    exit 1
  fi

  mkdir -p "$dst_dir"
  local f
  for f in "$src_dir"/*.go; do
    [[ -e "$f" ]] || continue
    cp "$f" "$dst_dir/"
    echo "  $rel/$(basename "$f")"
  done
}

DEST=""
WITH_STDIOPIPE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdiopipe) WITH_STDIOPIPE=1; shift ;;
    -h|--help) usage ;;
    -*) echo "Error: unknown option: $1" >&2; usage ;;
    *)
      if [[ -n "$DEST" ]]; then
        echo "Error: unexpected argument: $1" >&2
        usage
      fi
      DEST="$1"; shift ;;
  esac
done

if [[ -z "$DEST" ]]; then
  echo "Error: provide a project root" >&2
  usage
fi
if [[ ! -d "$DEST" ]]; then
  echo "Error: project root does not exist: $DEST" >&2
  exit 1
fi

echo "Copying helpers into $DEST"
for d in "${ALWAYS_DIRS[@]}"; do
  copy_dir "$d"
done
if [[ "$WITH_STDIOPIPE" -eq 1 ]]; then
  copy_dir "$STDIOPIPE_DIR"
fi
