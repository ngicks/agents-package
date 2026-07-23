///|
async fn touch_file(path : String) -> Unit {
  @fs.write_file(path, "", create_mode=@fs.CreateOrTruncate)
}

///|
fn kind_label(k : @discover.Kind) -> String {
  match k {
    @discover.ApmPackage => "ApmPackage"
    @discover.HookPackage => "HookPackage"
    @discover.InstructionFile => "InstructionFile"
    @discover.MarketplacePlugin => "MarketplacePlugin"
    @discover.Skill => "Skill"
  }
}

///|
/// units_repr renders discovered units, one per line, in the order returned by
/// `discover` (so the snapshot doubles as an assertion of the sort order).
fn units_repr(units : Array[@discover.ApmUnit]) -> String {
  let mut out = ""
  for u in units {
    out = out + kind_label(u.kind) + " " + u.repo_path + "\n"
  }
  out
}

///|
/// build_full_tree lays out a fixture exercising every root, both plugin
/// markers, a nested (two-level-deep) apm package, and a skill marker nested
/// beneath another skill marker (to prove the walk stops descending).
async fn build_full_tree(root : String) -> Unit {
  // apm packages: one at depth 1 (apm.yml), one nested at depth 2 (apm.yaml).
  @fs.mkdir("\{root}/apm-package/cc-workers/.apm", recursive=true)
  touch_file("\{root}/apm-package/cc-workers/apm.yml")
  @fs.mkdir("\{root}/apm-package/group/nested-pkg/.apm", recursive=true)
  touch_file("\{root}/apm-package/group/nested-pkg/apm.yaml")
  // hook package: dir containing a `hooks/` subdirectory.
  @fs.mkdir("\{root}/hooks/go-vet/hooks", recursive=true)
  touch_file("\{root}/hooks/go-vet/hooks/config.json")
  // instruction files: one directly under the root, one nested.
  @fs.mkdir("\{root}/instructions/nested", recursive=true)
  touch_file("\{root}/instructions/x.instructions.md")
  touch_file("\{root}/instructions/nested/y.instructions.md")
  // marketplace plugins: `plugin.json` marker and `.claude-plugin/` marker.
  @fs.mkdir("\{root}/plugins/plug-json", recursive=true)
  touch_file("\{root}/plugins/plug-json/plugin.json")
  @fs.mkdir("\{root}/plugins/plug-dir/.claude-plugin", recursive=true)
  // skills: `skills/outer` is a marker; `skills/outer/inner` is another marker
  // that must NOT be reported because descent stops at `skills/outer`.
  @fs.mkdir("\{root}/skills/alpha", recursive=true)
  touch_file("\{root}/skills/alpha/SKILL.md")
  @fs.mkdir("\{root}/skills/outer/inner", recursive=true)
  touch_file("\{root}/skills/outer/SKILL.md")
  touch_file("\{root}/skills/outer/inner/SKILL.md")
}

///|
async test "discover full tree, sorted and deterministic" {
  let root = @fs.tmpdir(prefix="discover_full")
  build_full_tree(root)
  let units = @discover.discover(root, exclude=[])
  @fs.rmdir(root, recursive=true)
  inspect(
    units_repr(units),
    content=(
      #|ApmPackage apm-package/cc-workers
      #|ApmPackage apm-package/group/nested-pkg
      #|HookPackage hooks/go-vet
      #|InstructionFile instructions/nested/y.instructions.md
      #|InstructionFile instructions/x.instructions.md
      #|MarketplacePlugin plugins/plug-dir
      #|MarketplacePlugin plugins/plug-json
      #|Skill skills/alpha
      #|Skill skills/outer
      #|
    ),
  )
}

///|
async test "discover applies exclude globs" {
  let root = @fs.tmpdir(prefix="discover_excl")
  build_full_tree(root)
  let filtered = @discover.discover(root, exclude=[
    "instructions/**", "skills/outer",
  ])
  @fs.rmdir(root, recursive=true)
  inspect(
    units_repr(filtered),
    content=(
      #|ApmPackage apm-package/cc-workers
      #|ApmPackage apm-package/group/nested-pkg
      #|HookPackage hooks/go-vet
      #|MarketplacePlugin plugins/plug-dir
      #|MarketplacePlugin plugins/plug-json
      #|Skill skills/alpha
      #|
    ),
  )
}

///|
async test "discover skips absent roots silently" {
  let root = @fs.tmpdir(prefix="discover_absent")
  // Only the skills/ root exists; the other four roots are absent.
  @fs.mkdir("\{root}/skills/solo", recursive=true)
  touch_file("\{root}/skills/solo/SKILL.md")
  let units = @discover.discover(root, exclude=[])
  @fs.rmdir(root, recursive=true)
  inspect(
    units_repr(units),
    content=(
      #|Skill skills/solo
      #|
    ),
  )
}

///|
async test "discover ignores symlinks (cycles and escapes)" {
  let root = @fs.tmpdir(prefix="discover_symlink")
  let outside = @fs.tmpdir(prefix="discover_outside")
  // A valid skill living OUTSIDE the walked tree.
  @fs.mkdir("\{outside}/ext-skill", recursive=true)
  touch_file("\{outside}/ext-skill/SKILL.md")
  // A real, in-tree skill — the only unit that must be reported.
  @fs.mkdir("\{root}/skills/real", recursive=true)
  touch_file("\{root}/skills/real/SKILL.md")
  // (a) a symlink cycle: skills/loop points at the skills root itself.
  @fs.symlink("\{root}/skills/loop", target="\{root}/skills")
  // (b) a symlink escaping the tree at a directory that contains SKILL.md.
  @fs.symlink("\{root}/skills/external", target="\{outside}/ext-skill")
  let units = @discover.discover(root, exclude=[])
  @fs.rmdir(root, recursive=true)
  @fs.rmdir(outside, recursive=true)
  // Discovery terminates (no cycle followed) and reports only the real skill;
  // the escaping symlink is not indexed.
  inspect(
    units_repr(units),
    content=(
      #|Skill skills/real
      #|
    ),
  )
}

///|
async test "discover raises when apm-package lacks its manifest" {
  let root = @fs.tmpdir(prefix="discover_bad")
  // `.apm/` present but neither apm.yml nor apm.yaml.
  @fs.mkdir("\{root}/apm-package/broken/.apm", recursive=true)
  let outcome = try {
    let _units = @discover.discover(root, exclude=[])
    "no error raised"
  } catch {
    @discover.DiscoverError(msg) => msg
    err => raise err
  }
  @fs.rmdir(root, recursive=true)
  inspect(
    outcome,
    content=(
      #|apm-package unit 'apm-package/broken' contains .apm/ but has neither apm.yml nor apm.yaml
    ),
  )
}
