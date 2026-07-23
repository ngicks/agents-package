#!/usr/bin/env bash
#
# Acceptance test for the `tool gen-apm-yml` MoonBit CLI.
#
# Builds the native binary, then exercises it end-to-end against this repository:
# expected 17-unit dep set (exact order), git derivation+normalization,
# determinism, every flag, and (best-effort) an `apm install` round trip.
#
# Prints PASS/SKIP/FAIL per step and exits non-zero if any assertion fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$SCRIPT_DIR/_build/native/debug/build/cmd/main/main.exe"
EXPECTED_GIT="github.com/ngicks/agents-package"

# The 17 importable units, in the deterministic order the tool emits
# (fixed kind order: apm-package, hooks, instructions, plugins, skills;
#  lexicographic within each kind).
read -r -d '' EXPECTED_PATHS <<'EOF' || true
apm-package/cc-workers
hooks/go-vet-ngcheckers
hooks/goimports-after-edit
hooks/golangci-lint-fmt-after-edit
hooks/golangci-lint-run-after-edit
instructions/base-env.instructions.md
instructions/base-preference.instructions.md
instructions/go/go-basics.instructions.md
instructions/go/go-design-preference.instructions.md
instructions/moonbit/moonbit-basics.instructions.md
skills/go-check-outdated-patterns
skills/go-edit-cobra
skills/go-review-checklist
skills/kvm-in-container
skills/nggoal
skills/ngplan
skills/nix-update-hash
EOF

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

FAILS=0
pass() { printf 'PASS: %s\n' "$1"; }
skip() { printf 'SKIP: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }

# --- YAML extraction helpers (prefer yq; fall back to awk on the fixed shape) ---
paths_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.dependencies.apm[].path' "$1"
  else
    awk '/^[[:space:]]*path:/ {print $2}' "$1"
  fi
}
gits_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.dependencies.apm[].git' "$1"
  else
    awk '/^[[:space:]]*git:/ {print $2}' "$1"
  fi
}
refs_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.dependencies.apm[] | .ref // empty' "$1"
  else
    awk '/^[[:space:]]*ref:/ {print $2}' "$1"
  fi
}
name_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.name' "$1"
  else
    awk '/^name:/ {print $2}' "$1"
  fi
}
version_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.version' "$1"
  else
    awk '/^version:/ {print $2}' "$1"
  fi
}
# Paths recorded in an apm.lock.yaml (each dependency's virtual_path).
lock_paths_of() {
  if command -v yq >/dev/null 2>&1; then
    yq -r '.dependencies[].virtual_path' "$1"
  else
    awk '/[[:space:]]*virtual_path:/ {print $2}' "$1"
  fi
}

# Run the binary from a neutral (non-repo) cwd so git derivation is proven to
# use --root, not the current directory.
run_tool() { ( cd "$WORK" && "$BIN" "$@" ); }

# ===========================================================================
echo "== Step 1: moon build --target native =="
build_ok=0
for attempt in 1 2 3 4 5; do
  if ( cd "$SCRIPT_DIR" && moon build --target native ) >"$WORK/build.log" 2>&1; then
    build_ok=1
    break
  fi
  if grep -qiE 'lock|being used|waiting|resource temporarily' "$WORK/build.log"; then
    echo "  build lock contention (attempt $attempt), retrying..." >&2
    sleep 2
    continue
  fi
  break
done
if [ "$build_ok" -eq 1 ] && [ -x "$BIN" ]; then
  pass "build produced $BIN"
else
  cat "$WORK/build.log" >&2
  fail "moon build failed or binary missing"
  echo "== SUMMARY: build failed, aborting =="
  exit 1
fi

# ===========================================================================
echo "== Step 2: gen-apm-yml --root <repo> (exact 17-unit set, derived git) =="
rc=0
run_tool gen-apm-yml --root "$REPO_ROOT" >"$WORK/s2.yml" 2>"$WORK/s2.err" || rc=$?
if [ "$rc" -eq 0 ]; then pass "exit 0"; else fail "expected exit 0, got $rc"; fi
if [ ! -s "$WORK/s2.err" ]; then pass "stderr empty"; else fail "stderr not empty: $(cat "$WORK/s2.err")"; fi

got_paths="$(paths_of "$WORK/s2.yml")"
if [ "$got_paths" = "$EXPECTED_PATHS" ]; then
  pass "dep path set matches the 17 expected paths in exact order"
else
  fail "dep path set/order mismatch"
  diff <(printf '%s\n' "$EXPECTED_PATHS") <(printf '%s\n' "$got_paths") || true
fi

dup_count="$(printf '%s\n' "$got_paths" | sort | uniq -d | wc -l | tr -d ' ')"
if [ "$dup_count" -eq 0 ]; then pass "no duplicate paths"; else fail "$dup_count duplicate path(s)"; fi

uniq_gits="$(gits_of "$WORK/s2.yml" | sort -u)"
if [ "$uniq_gits" = "$EXPECTED_GIT" ]; then
  pass "every git: equals derived+normalized '$EXPECTED_GIT'"
else
  fail "git values not all '$EXPECTED_GIT': got [$uniq_gits]"
fi

# ===========================================================================
echo "== Step 3: determinism (two runs byte-identical) =="
run_tool gen-apm-yml --root "$REPO_ROOT" >"$WORK/s3a.yml"
run_tool gen-apm-yml --root "$REPO_ROOT" >"$WORK/s3b.yml"
if cmp -s "$WORK/s3a.yml" "$WORK/s3b.yml"; then pass "two runs are byte-identical"; else fail "outputs differ between runs"; fi

# ===========================================================================
echo "== Step 4: flag coverage =="

# --ref: every entry gains ref: deadbeef
run_tool gen-apm-yml --root "$REPO_ROOT" --ref deadbeef >"$WORK/s4ref.yml"
ref_lines="$(refs_of "$WORK/s4ref.yml" | grep -c '^deadbeef$' || true)"
bad_ref="$(refs_of "$WORK/s4ref.yml" | grep -vc '^deadbeef$' || true)"
if [ "$ref_lines" -eq 17 ] && [ "$bad_ref" -eq 0 ]; then
  pass "--ref deadbeef sets ref on all 17 entries"
else
  fail "--ref: expected 17 'deadbeef' refs and no others, got $ref_lines matching / $bad_ref other"
fi

# --exclude: instructions/** removes exactly the 5 instruction entries -> 12 left
run_tool gen-apm-yml --root "$REPO_ROOT" --exclude 'instructions/**' >"$WORK/s4ex.yml"
ex_count="$(paths_of "$WORK/s4ex.yml" | grep -c . || true)"
ex_instr="$(paths_of "$WORK/s4ex.yml" | grep -c '^instructions/' || true)"
if [ "$ex_count" -eq 12 ] && [ "$ex_instr" -eq 0 ]; then
  pass "--exclude 'instructions/**' leaves 12 entries, no instructions/ paths"
else
  fail "--exclude: expected 12 entries and 0 instructions, got $ex_count entries / $ex_instr instructions"
fi

# -o: creates parent dirs; content identical to stdout run; no temp file left
OUT="$WORK/nested/deep/dir/apm.yml"
rc=0
run_tool gen-apm-yml --root "$REPO_ROOT" -o "$OUT" || rc=$?
run_tool gen-apm-yml --root "$REPO_ROOT" >"$WORK/s4stdout.yml"
if [ "$rc" -eq 0 ] && [ -f "$OUT" ]; then
  pass "-o created nested parent dirs and wrote the file"
else
  fail "-o did not create the file (rc=$rc)"
fi
if [ -f "$OUT" ] && cmp -s "$OUT" "$WORK/s4stdout.yml"; then
  pass "-o file content is byte-identical to the stdout run"
else
  fail "-o file content differs from stdout run"
fi
OUT_DIR="$(dirname "$OUT")"
tmp_leftover="$(find "$OUT_DIR" -maxdepth 1 -name '*.tmp' | wc -l | tr -d ' ')"
if [ "$tmp_leftover" -eq 0 ]; then
  pass "-o left no temp file behind"
else
  fail "-o left $tmp_leftover temp file(s) in $OUT_DIR"
fi

# --git: overrides every entry's git value
run_tool gen-apm-yml --root "$REPO_ROOT" --git example.com/x/y >"$WORK/s4git.yml"
override_gits="$(gits_of "$WORK/s4git.yml" | sort -u)"
if [ "$override_gits" = "example.com/x/y" ]; then
  pass "--git example.com/x/y overrides all git values"
else
  fail "--git override failed: got [$override_gits]"
fi

# --name / --pkg-version land in the emitted top-level keys
run_tool gen-apm-yml --root "$REPO_ROOT" --name my-index --pkg-version 9.9.9 >"$WORK/s4nv.yml"
got_name="$(name_of "$WORK/s4nv.yml")"
got_ver="$(version_of "$WORK/s4nv.yml")"
if [ "$got_name" = "my-index" ] && [ "$got_ver" = "9.9.9" ]; then
  pass "--name/--pkg-version land in the emitted name:/version: keys"
else
  fail "--name/--pkg-version: got name='$got_name' version='$got_ver'"
fi

# Repeated --exclude proves the Append action: instructions/** + skills/**
# leaves exactly the 5 remaining units (1 apm-package + 4 hooks).
run_tool gen-apm-yml --root "$REPO_ROOT" \
  --exclude 'instructions/**' --exclude 'skills/**' >"$WORK/s4ex2.yml"
got_ex2="$(paths_of "$WORK/s4ex2.yml")"
read -r -d '' EXPECTED_EX2 <<'EOF' || true
apm-package/cc-workers
hooks/go-vet-ngcheckers
hooks/goimports-after-edit
hooks/golangci-lint-fmt-after-edit
hooks/golangci-lint-run-after-edit
EOF
if [ "$got_ex2" = "$EXPECTED_EX2" ]; then
  pass "repeated --exclude (Append) leaves exactly the 5 non-excluded units"
else
  fail "repeated --exclude mismatch"
  diff <(printf '%s\n' "$EXPECTED_EX2") <(printf '%s\n' "$got_ex2") || true
fi

# Usage error: unknown flag -> exit 2, empty stdout
rc=0
run_tool gen-apm-yml --root "$REPO_ROOT" --nope >"$WORK/s4usage.out" 2>"$WORK/s4usage.err" || rc=$?
if [ "$rc" -eq 2 ] && [ ! -s "$WORK/s4usage.out" ]; then
  pass "unknown flag -> exit 2 with empty stdout"
else
  fail "unknown flag: expected exit 2 + empty stdout, got rc=$rc, stdout bytes=$(wc -c <"$WORK/s4usage.out")"
fi

# Runtime error: discovery succeeds but git derivation fails (non-repo root)
FIX="$WORK/nonrepo"
mkdir -p "$FIX/skills/x"
printf '# x\n' >"$FIX/skills/x/SKILL.md"
rc=0
run_tool gen-apm-yml --root "$FIX" >"$WORK/s4fail.out" 2>"$WORK/s4fail.err" || rc=$?
if [ "$rc" -eq 1 ] && [ ! -s "$WORK/s4fail.out" ]; then
  pass "non-repo root (no --git) -> exit 1 with empty stdout"
else
  fail "non-repo root: expected exit 1 + empty stdout, got rc=$rc, stdout bytes=$(wc -c <"$WORK/s4fail.out")"
fi

# ===========================================================================
echo "== Step 5: apm install network e2e (derived GitHub git) =="
# NOTE: file:// is deliberately NOT used here. apm 0.26.0 rejects file:// URLs
# for security by design (config.py: "file:// paths are rejected"), and its
# git_file_transport is a sparse-checkout fetcher for git/ssh repos, not a
# file:// clone transport. So this step uses the real derived GitHub reference
# and needs network. A network probe gates it; an unreachable network is the
# ONLY allowed skip.
if ! command -v apm >/dev/null 2>&1; then
  skip "apm not on PATH"
elif ! timeout 30 git ls-remote https://github.com/ngicks/agents-package HEAD >/dev/null 2>&1; then
  skip "network unavailable (git ls-remote github.com/ngicks/agents-package failed)"
else
  CONSUMER="$WORK/consumer"
  mkdir -p "$CONSUMER"
  # Generate with the derived git value (no --git) -> github.com/ngicks/agents-package.
  "$BIN" gen-apm-yml --root "$REPO_ROOT" >"$CONSUMER/apm.yml"
  # Deployment target is the consumer's to choose; apm 0.26 refuses to install
  # without one. This is the consumer-owned key the PLAN says consumers set.
  printf 'targets:\n  - claude\n' >>"$CONSUMER/apm.yml"
  rc=0
  ( cd "$CONSUMER" && timeout 300 apm install </dev/null ) >"$WORK/apm.log" 2>&1 || rc=$?
  LOCK="$CONSUMER/apm.lock.yaml"
  if [ "$rc" -ne 0 ]; then
    tail -20 "$WORK/apm.log" >&2
    fail "apm install failed (rc=$rc); see log above"
  elif [ ! -f "$LOCK" ]; then
    fail "apm install reported success but wrote no lockfile ($LOCK)"
  else
    lock_paths="$(lock_paths_of "$LOCK" | sort)"
    expected_sorted="$(printf '%s\n' "$EXPECTED_PATHS" | sort)"
    if [ "$lock_paths" = "$expected_sorted" ]; then
      pass "apm install succeeded; lockfile references exactly the 17 expected paths"
    else
      fail "apm.lock.yaml path set mismatch"
      diff <(printf '%s\n' "$expected_sorted") <(printf '%s\n' "$lock_paths") >&2 || true
    fi
  fi
fi

# ===========================================================================
echo "== SUMMARY =="
if [ "$FAILS" -eq 0 ]; then
  echo "ALL ASSERTIONS PASSED (step 5 is SKIPPED only when the network is unavailable)"
  exit 0
else
  echo "$FAILS ASSERTION(S) FAILED"
  exit 1
fi
