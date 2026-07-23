///|
/// gen_apm_yml is the handler for `tool gen-apm-yml`. It discovers every
/// importable unit under `--root`, maps each to an apm dependency carrying the
/// resolved git reference (and optional `--ref`), emits the manifest, and
/// writes it to stdout (default) or, with `-o/--output`, atomically to a file.
async fn gen_apm_yml(m : @argparse.Matches) -> Unit {
  let root_arg = opt_or(m, "root", ".")
  let name = opt_or(m, "name", "agents-package-index")
  let version = opt_or(m, "pkg-version", "0.0.1")
  let ref_ = opt(m, "ref")
  let output = opt(m, "output")
  let exclude = m.values.get("exclude").unwrap_or([])

  // --root is realpath'd before anything else touches the filesystem.
  let root = @fs.realpath(root_arg)

  // --git wins; otherwise derive from `git remote get-url origin` in the root.
  let git = match opt(m, "git") {
    Some(g) => g
    None => derive_git(root)
  }
  let units = @discover.discover(root, exclude~)
  let deps = units.map(u => {
    @apmyml.ApmDependency::new(git~, path=u.repo_path, ref_?)
  })
  let manifest = @apmyml.Manifest::new(
    name~,
    version~,
    dependencies=@apmyml.Dependencies::new(apm=deps),
  )
  let doc = manifest.emit()
  match output {
    Some(path) => write_atomic(path, doc)
    None => @stdio.stdout.write(doc)
  }
}

///|
/// derive_git resolves the repository's git reference by running
/// `git remote get-url origin` in `root` and normalizing the result. A non-zero
/// exit or empty output raises `CliError` telling the user to pass `--git`.
async fn derive_git(root : String) -> String {
  let (code, out, err) = @process.collect_output(
    "git",
    ["remote", "get-url", "origin"],
    cwd=root,
  )
  if code != 0 {
    let detail = err.text().trim().to_owned()
    let suffix = if detail != "" { ": \{detail}" } else { "" }
    raise CliError(
      "could not derive git reference: `git remote get-url origin` failed in '\{root}'\{suffix}. Pass --git <url> explicitly.",
    )
  }
  let normalized = normalize_git(out.text())
  if normalized == "" {
    raise CliError(
      "could not derive git reference: `git remote get-url origin` produced no output in '\{root}'. Pass --git <url> explicitly.",
    )
  }
  normalized
}

///|
/// normalize_git turns a clone URL into the scheme-less shorthand apm accepts as
/// a `git:` value:
///
/// - trim surrounding whitespace/newlines
/// - strip a leading `<scheme>://` (https, ssh, git, ...)
/// - strip a leading `user@` when it precedes the first `/` (ssh/scp forms)
/// - rewrite the scp host separator `host:owner/repo` -> `host/owner/repo`,
///   but ONLY for scp-form URLs (no explicit scheme). A pre-path colon in a
///   `<scheme>://host:port/...` URL is a PORT and is preserved — apm's
///   shorthand parser accepts `host:port/owner/repo`. scp syntax cannot express
///   a port, so the presence of a scheme disambiguates the two cases.
/// - strip a trailing `.git`
///
/// Examples:
///   https://github.com/o/r          -> github.com/o/r
///   https://github.com/o/r.git      -> github.com/o/r
///   https://github.com:8443/o/r.git -> github.com:8443/o/r   (port kept)
///   ssh://git@github.com:7999/o/r    -> github.com:7999/o/r   (port kept)
///   git@github.com:o/r.git          -> github.com/o/r        (scp separator)
///   github.com/o/r                  -> github.com/o/r        (unchanged)
fn normalize_git(raw : String) -> String {
  let trimmed = raw.trim().to_owned()
  // A "<scheme>://" prefix decides how a pre-path colon is read below: with a
  // scheme it is a port (kept); without one it is the scp host/owner separator.
  let has_scheme = trimmed.contains("://")
  // Strip a leading "<scheme>://".
  let s = match trimmed.find("://") {
    Some(i) => trimmed[i + 3:].to_owned()
    None => trimmed
  }
  // Strip a leading "user@" when it comes before the first path separator.
  let s = match s.find("@") {
    Some(at) if before_first_slash(s, at) => s[at + 1:].to_owned()
    _ => s
  }
  // Rewrite the scp separator `host:owner` -> `host/owner` (first ':' before
  // the first '/') for scp-form URLs only; keep it for scheme URLs (it's a port).
  let s = match s.find(":") {
    Some(colon) if !has_scheme && before_first_slash(s, colon) =>
      "\{s[:colon]}/\{s[colon + 1:]}"
    _ => s
  }
  // Strip a trailing ".git".
  let s = match s {
    [.. rest, .. ".git"] => rest.to_owned()
    _ => s
  }
  s.trim().to_owned()
}

///|
/// before_first_slash reports whether index `i` in `s` precedes the first `/`
/// (or `s` has no `/` at all).
fn before_first_slash(s : String, i : Int) -> Bool {
  match s.find("/") {
    Some(slash) => i < slash
    None => true
  }
}

///|
/// write_atomic writes `doc` to `path` durably: it creates the parent
/// directories, writes a sibling temp file, then renames it over the target
/// (same-directory rename is the atomicity mechanism). Existing targets are
/// overwritten silently.
///
/// The temp file name embeds the process id (`<path>.<pid>.tmp`) so a
/// concurrent invocation cannot clobber, publish, or be published-over by this
/// one, and an unrelated pre-existing `<path>.tmp` is never touched. On any
/// failure the temp file is removed best-effort before the error is re-raised,
/// so a partial write never leaks.
async fn write_atomic(path : String, doc : String) -> Unit {
  let parent = parent_dir(path)
  if parent != "." && parent != "" && !@fs.exists(parent) {
    @fs.mkdir(parent, recursive=true)
  }
  let temp = "\{path}.\{get_pid()}.tmp"
  try {
    @fs.write_file(temp, doc, create_mode=@fs.CreateOrTruncate)
    @fs.rename(temp, path)
  } catch {
    e => {
      // Best-effort cleanup of the temp file; ignore any secondary error.
      @fs.remove(temp) catch {
        _ => ()
      }
      raise e
    }
  }
}

///|
/// parent_dir returns the directory portion of `path` ("." when there is no
/// separator, "/" when the separator is the leading one).
fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => if i == 0 { "/" } else { path[:i].to_owned() }
    None => "."
  }
}

///|
/// opt returns the (last) value collected for option `key`, or `None` when the
/// option was neither supplied nor defaulted.
fn opt(m : @argparse.Matches, key : String) -> String? {
  match m.values.get(key) {
    Some([.., last]) => Some(last)
    _ => None
  }
}

///|
/// opt_or returns `opt(m, key)` or `fallback` when absent.
fn opt_or(m : @argparse.Matches, key : String, fallback : String) -> String {
  opt(m, key).unwrap_or(fallback)
}
