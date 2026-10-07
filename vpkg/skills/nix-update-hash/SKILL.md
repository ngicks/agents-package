---
name: nix-update-hash
description: "Use this skill to update Nix package hashes. Triggers on: 'update hash', 'update vendorHash', 'nix hash', 'fix hash mismatch', 'prefetch hash'. Use when modifying or creating Nix packages that need vendorHash or GitHub source hash updates."
---

# Nix Update Hash

Compute correct hashes for Nix package definitions.

## Commands

### Vendor Hash (for `buildGoModule` packages)

Computes the correct `vendorHash` by building with `lib.fakeHash` and extracting the real hash.

**Single package:**
```bash
"$SKILL_DIR/nix-update-hash.sh" vendor <pkgs-dir> <pkg-name>
```

**All packages in directory:**
```bash
"$SKILL_DIR/nix-update-hash.sh" vendor <pkgs-dir>
```

**Examples:**
```bash
# Single package — resolves to nix-craft/pkgs/lsp-gw.nix
"$SKILL_DIR/nix-update-hash.sh" vendor nix-craft/pkgs lsp-gw

# All .nix files in the directory
"$SKILL_DIR/nix-update-hash.sh" vendor nix-craft/pkgs
```

After getting the hash, update the `vendorHash` field in the `.nix` file.

### GitHub Source Hash

Prefetches a GitHub repo at a specific revision and returns the hash:

```bash
"$SKILL_DIR/nix-update-hash.sh" github <owner> <repo> <rev>
```

**Example:**
```bash
"$SKILL_DIR/nix-update-hash.sh" github neovim go-client v1.2.3
```

## Workflow

1. Identify the Nix package file that needs a hash update
2. Run the appropriate subcommand to compute the correct hash
3. Update the hash field in the `.nix` file with the result

## Output

Both commands print the hash string to stdout (e.g., `sha256-...`). Errors go to stderr with a non-zero exit code.

## Notes

- The `vendor` subcommand requires `nix-build` and access to `<nixpkgs>`
- The `github` subcommand requires `nix flake prefetch` (experimental features: nix-command, flakes) and `jq`
- Vendor hash computation involves a full build attempt, so it may take some time
