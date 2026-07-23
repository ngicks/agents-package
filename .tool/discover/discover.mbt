///|
/// Kind classifies an importable unit discovered under one of the fixed
/// repository roots. The declaration order is also the deterministic sort
/// order used by `discover`.
pub(all) enum Kind {
  ApmPackage
  HookPackage
  InstructionFile
  MarketplacePlugin
  Skill
} derive(Eq)

///|
pub impl Show for Kind with fn output(self, logger) {
  logger.write_string(
    match self {
      ApmPackage => "ApmPackage"
      HookPackage => "HookPackage"
      InstructionFile => "InstructionFile"
      MarketplacePlugin => "MarketplacePlugin"
      Skill => "Skill"
    },
  )
}

///|
/// ApmUnit is a single importable unit discovered in the repository.
///
/// `repo_path` is repository-relative and always '/'-separated (e.g.
/// "skills/go-edit-cobra" or "instructions/foo.instructions.md").
pub struct ApmUnit {
  repo_path : String
  kind : Kind
} derive(Eq)

///|
pub impl Show for ApmUnit with fn output(self, logger) {
  Show::output(self.kind, logger)
  logger.write_string(" ")
  logger.write_string(self.repo_path)
}

///|
/// DiscoverError is raised when a repository invariant is violated, e.g. an
/// apm-package marker directory that contains `.apm/` but neither `apm.yml`
/// nor `apm.yaml`. Discovery fails closed rather than index a broken package.
pub suberror DiscoverError {
  DiscoverError(String)
}

///|
pub impl Show for DiscoverError with fn output(self, logger) {
  let DiscoverError(msg) = self
  logger.write_string(msg)
}

///|
/// DirEntry is a single directory entry classified WITHOUT following symlinks:
/// `is_dir` is true only for a real directory and `is_file` only for a regular
/// file. A symbolic link (or any other special entry) has both false, so it is
/// invisible to every marker predicate. It is the input to the (pure) marker
/// predicates so they can be unit-tested without touching the filesystem.
priv struct DirEntry {
  name : String
  is_dir : Bool
  is_file : Bool
}

// ---------------------------------------------------------------------------
// Marker predicates (pure)
// ---------------------------------------------------------------------------

///|
/// is_apm_package_dir reports whether a directory's entries contain the `.apm/`
/// marker directory that identifies an apm package.
fn is_apm_package_dir(entries : Array[DirEntry]) -> Bool {
  entries.any(e => e.name == ".apm" && e.is_dir)
}

///|
/// has_apm_manifest reports whether a directory contains an `apm.yml` or
/// `apm.yaml` manifest file.
fn has_apm_manifest(entries : Array[DirEntry]) -> Bool {
  entries.any(e => (e.name == "apm.yml" || e.name == "apm.yaml") && e.is_file)
}

///|
/// is_hook_package_dir reports whether a directory contains a `hooks/`
/// subdirectory, the marker for a hook package.
fn is_hook_package_dir(entries : Array[DirEntry]) -> Bool {
  entries.any(e => e.name == "hooks" && e.is_dir)
}

///|
/// is_marketplace_plugin_dir reports whether a directory contains a
/// `plugin.json` file or a `.claude-plugin/` directory, either of which marks
/// a marketplace plugin.
fn is_marketplace_plugin_dir(entries : Array[DirEntry]) -> Bool {
  entries.any(e => {
    (e.name == "plugin.json" && e.is_file) ||
    (e.name == ".claude-plugin" && e.is_dir)
  })
}

///|
/// is_skill_dir reports whether a directory contains a `SKILL.md` file, the
/// marker for a skill.
fn is_skill_dir(entries : Array[DirEntry]) -> Bool {
  entries.any(e => e.name == "SKILL.md" && e.is_file)
}

///|
fn kind_order(k : Kind) -> Int {
  match k {
    ApmPackage => 0
    HookPackage => 1
    InstructionFile => 2
    MarketplacePlugin => 3
    Skill => 4
  }
}

// ---------------------------------------------------------------------------
// Filesystem helpers (thin IO)
// ---------------------------------------------------------------------------

///|
/// is_real_directory reports whether `path` is a directory, WITHOUT following
/// symlinks — a symlink (even one pointing at a directory) is never a real
/// directory, so it is never walked as a discovery root.
async fn is_real_directory(path : String) -> Bool {
  return @fs.kind(path, follow_symlink=false) is @fs.Directory
}

///|
/// read_entries lists `dir` and classifies every entry WITHOUT following
/// symlinks: `is_dir` is set only for real directories, `is_file` only for
/// regular files. Symlinks and other special entries are neither, so discovery
/// never descends into them nor treats them as file markers. This makes the
/// walk immune to symlink cycles and symlinks escaping the tree. Entries are
/// returned sorted by name.
async fn read_entries(dir : String) -> Array[DirEntry] {
  let names = @fs.readdir(dir, sort=true)
  let out : Array[DirEntry] = []
  for name in names {
    let (is_dir, is_file) = match
      @fs.kind("\{dir}/\{name}", follow_symlink=false) {
      @fs.Directory => (true, false)
      @fs.Regular => (false, true)
      _ => (false, false)
    }
    out.push({ name, is_dir, is_file })
  }
  out
}

// ---------------------------------------------------------------------------
// Marker walks
// ---------------------------------------------------------------------------

///|
/// descend_dirs recursively walks directories under `rel` (repository-relative)
/// looking for the marker recognised by `is_marker`. When a directory matches,
/// it becomes a unit and the descent stops there — nothing beneath a marker is
/// scanned. For `ApmPackage` the marker directory must also carry an
/// `apm.y[a]ml` manifest, otherwise a `DiscoverError` is raised.
async fn descend_dirs(
  base : String,
  rel : String,
  is_marker : (Array[DirEntry]) -> Bool,
  kind : Kind,
  units : Array[ApmUnit],
) -> Unit {
  let entries = read_entries("\{base}/\{rel}")
  if is_marker(entries) {
    if kind is ApmPackage && !has_apm_manifest(entries) {
      raise DiscoverError(
        "apm-package unit '\{rel}' contains .apm/ but has neither apm.yml nor apm.yaml",
      )
    }
    units.push({ repo_path: rel, kind })
    return
  }
  for e in entries {
    if e.is_dir {
      descend_dirs(base, "\{rel}/\{e.name}", is_marker, kind, units)
    }
  }
}

///|
/// walk_dir_root walks a directory-marker root (apm-package, hooks, plugins,
/// skills). The root container itself is never a unit; only its descendants
/// are candidates. An absent root is skipped silently.
async fn walk_dir_root(
  base : String,
  root : String,
  is_marker : (Array[DirEntry]) -> Bool,
  kind : Kind,
  units : Array[ApmUnit],
) -> Unit {
  let root_path = "\{base}/\{root}"
  if !@fs.exists(root_path) {
    return
  }
  if !is_real_directory(root_path) {
    return
  }
  for e in read_entries(root_path) {
    if e.is_dir {
      descend_dirs(base, "\{root}/\{e.name}", is_marker, kind, units)
    }
  }
}

///|
/// scan_instruction_files recursively records every file suffixed
/// `.instructions.md` under `rel` as an InstructionFile unit.
async fn scan_instruction_files(
  base : String,
  rel : String,
  units : Array[ApmUnit],
) -> Unit {
  for e in read_entries("\{base}/\{rel}") {
    let child = "\{rel}/\{e.name}"
    if e.is_dir {
      scan_instruction_files(base, child, units)
    } else if e.is_file && e.name.has_suffix(".instructions.md") {
      units.push({ repo_path: child, kind: InstructionFile })
    }
  }
}

///|
/// walk_instructions_root walks the file-marker root `instructions/`. An absent
/// root is skipped silently.
async fn walk_instructions_root(base : String, units : Array[ApmUnit]) -> Unit {
  let root_path = "\{base}/instructions"
  if !@fs.exists(root_path) {
    return
  }
  if !is_real_directory(root_path) {
    return
  }
  scan_instruction_files(base, "instructions", units)
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

///|
/// discover walks the five fixed top-level roots under `root`
/// (apm-package/, hooks/, instructions/, plugins/, skills/) and returns every
/// importable unit found.
///
/// Each root has a marker that both identifies a unit and stops the descent:
/// the walk is recursive until the marker, and nothing beneath a marker is
/// scanned. A root that does not exist is skipped silently.
///
/// Symlinks are never followed and are invisible to discovery: a symbolic link
/// is never descended into (even if it points at a directory) and never counts
/// as a file marker (even if it points at a `SKILL.md`/`plugin.json`/`apm.yml`/
/// `*.instructions.md`). This keeps the walk terminating in the presence of
/// symlink cycles and prevents symlinks from reaching outside the walked roots.
///
/// `exclude` is a list of globs matched against the repository-relative,
/// '/'-separated `repo_path` of each unit (see `glob_match`); any unit matching
/// at least one glob is dropped.
///
/// The result is sorted deterministically: by `Kind` in the fixed order
/// ApmPackage, HookPackage, InstructionFile, MarketplacePlugin, Skill, then
/// lexicographically by `repo_path` within each kind.
///
/// Raises `DiscoverError` if an apm-package marker directory lacks its
/// `apm.y[a]ml` manifest.
pub async fn discover(
  root : String,
  exclude~ : Array[String],
) -> Array[ApmUnit] {
  let units : Array[ApmUnit] = []
  walk_dir_root(root, "apm-package", is_apm_package_dir, ApmPackage, units)
  walk_dir_root(root, "hooks", is_hook_package_dir, HookPackage, units)
  walk_instructions_root(root, units)
  walk_dir_root(
    root,
    "plugins",
    is_marketplace_plugin_dir,
    MarketplacePlugin,
    units,
  )
  walk_dir_root(root, "skills", is_skill_dir, Skill, units)
  let filtered = units.filter(u => !exclude.any(g => glob_match(g, u.repo_path)))
  // NOTE: sort with an explicit comparator. `String`'s default `Compare`
  // (and hence tuple-key sorting) orders by length first, not lexically, so we
  // use `lexical_compare` to get true dictionary order within each kind.
  filtered.sort_by((x, y) => {
    let by_kind = kind_order(x.kind) - kind_order(y.kind)
    if by_kind != 0 {
      by_kind
    } else {
      x.repo_path.lexical_compare(y.repo_path)
    }
  })
  filtered
}
