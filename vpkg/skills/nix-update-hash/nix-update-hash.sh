#!/usr/bin/env bash

set -e

usage() {
  echo "Usage:"
  echo "  $0 vendor <pkgs-dir> [pkg-name]"
  echo "  $0 github <owner> <repo> <rev>"
  echo ""
  echo "vendor: If pkg-name is given, computes vendorHash for <pkgs-dir>/<pkg-name>.nix."
  echo "        If omitted, computes vendorHash for all .nix files in <pkgs-dir>."
  exit 1
}

vendor_one() {
  local pkg_file="$1"
  local pkg_dir
  pkg_dir=$(cd "$(dirname "$pkg_file")" && pwd)
  local tmp_file
  tmp_file=$(mktemp /tmp/nix-hash-XXXXXX.nix)
  trap "rm -f '$tmp_file'" EXIT INT TERM HUP

  # Replace vendorHash with fakeHash, and resolve relative paths to absolute
  # so the temp file in /tmp can still find sources
  sed -e 's/vendorHash = ".*"/vendorHash = lib.fakeHash/' \
      -e "s|= \.\./|= ${pkg_dir}/../|g" \
      -e "s|= \./|= ${pkg_dir}/|g" \
      "$pkg_file" > "$tmp_file"

  local output
  output=$(nix-build --no-out-link -E "with import <nixpkgs> {}; callPackage $tmp_file {}" 2>&1 || true)

  local hash
  hash=$(echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*')
  if [[ -z "$hash" ]]; then
    echo "Error: could not extract hash for $pkg_file" >&2
    echo "$output" >&2
    return 1
  fi

  echo "$hash"
}

cmd_vendor() {
  local pkgs_dir="$1"
  local pkg_name="${2:-}"

  if [[ -z "$pkgs_dir" || ! -d "$pkgs_dir" ]]; then
    echo "Error: provide a valid pkgs directory" >&2
    usage
  fi

  if [[ -n "$pkg_name" ]]; then
    local pkg_file="${pkgs_dir}/${pkg_name}.nix"
    if [[ ! -f "$pkg_file" ]]; then
      echo "Error: $pkg_file not found" >&2
      exit 1
    fi
    vendor_one "$pkg_file"
  else
    local found=0
    for pkg_file in "$pkgs_dir"/*.nix; do
      [[ -f "$pkg_file" ]] || continue
      echo "$(basename "$pkg_file" .nix): $(vendor_one "$pkg_file")"
      found=1
    done
    if [[ "$found" -eq 0 ]]; then
      echo "Error: no .nix files found in $pkgs_dir" >&2
      exit 1
    fi
  fi
}

cmd_github() {
  local owner="$1" repo="$2" rev="$3"
  if [[ -z "$owner" || -z "$repo" || -z "$rev" ]]; then
    echo "Error: provide owner, repo, and rev" >&2
    usage
  fi

  nix flake prefetch --extra-experimental-features "nix-command flakes" "github:${owner}/${repo}/${rev}" --json | jq -r .hash
}

case "${1:-}" in
  vendor) shift; cmd_vendor "$@" ;;
  github) shift; cmd_github "$@" ;;
  *) usage ;;
esac
