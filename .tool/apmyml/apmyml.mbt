///|
/// Error raised by `Manifest::emit` when a scalar would be emitted in a form the
/// downstream apm YAML loader misinterprets. Carries a human-readable message
/// naming the offending field and value.
pub suberror EmitError {
  EmitError(String)
}

///|
/// An `apm.yml` manifest: the document model this repo emits as a dependency
/// template for other repos. This package is a pure model plus a YAML emitter;
/// it knows nothing about the filesystem, does no IO, and is not async.
///
/// Field/key names mirror the apm manifest schema (object form).
pub(all) struct Manifest {
  name : String
  version : String
  description : String?
  dependencies : Dependencies
}

///|
/// Dependency groups. `mcp` is kept for schema parity; it is empty in this repo
/// today but its contents ARE emitted (string-form entries) when non-empty.
pub(all) struct Dependencies {
  apm : Array[ApmDependency]
  mcp : Array[McpDependency]
}

///|
/// A single apm dependency in object form: a git reference plus a path inside
/// the repo, optionally pinned to a `ref`.
///
/// `ref_` carries the value emitted under the YAML key `ref`; the field is
/// spelled with a trailing underscore because `ref` is a reserved word in
/// MoonBit.
pub(all) struct ApmDependency {
  git : String
  path : String
  ref_ : String?
}

///|
/// An MCP dependency, emitted as a string-form entry (its `name`). Kept for
/// schema parity; empty in this repo today.
pub(all) struct McpDependency {
  name : String
}

///|
/// Build a `Manifest`. `description` defaults to `None` (the key is omitted
/// from the emitted YAML when absent).
pub fn Manifest::new(
  name~ : String,
  version~ : String,
  dependencies~ : Dependencies,
  description? : String,
) -> Manifest {
  { name, version, description, dependencies }
}

///|
/// Build a `Dependencies` group. `mcp` defaults to empty.
pub fn Dependencies::new(
  apm~ : Array[ApmDependency],
  mcp? : Array[McpDependency] = [],
) -> Dependencies {
  { apm, mcp }
}

///|
/// Build an `ApmDependency`. `ref_` (emitted as the YAML key `ref`) defaults to
/// `None` — the key is omitted from the emitted YAML when the entry is
/// unpinned.
pub fn ApmDependency::new(
  git~ : String,
  path~ : String,
  ref_? : String,
) -> ApmDependency {
  { git, path, ref_ }
}

///|
/// Build an `McpDependency`.
pub fn McpDependency::new(name~ : String) -> McpDependency {
  { name, }
}

///|
/// Emit the manifest as a YAML value with a stable, insertion-ordered key
/// layout: `name`, `version`, `description` (omitted when `None`),
/// `dependencies`.
///
/// This is the pure structural mapping. It does NOT validate scalars; callers
/// that produce a document for apm to consume should use `emit` instead, which
/// guards against the one scalar form the yaml lib mis-emits (see `emit`).
pub fn Manifest::to_yaml(self : Self) -> @yaml.Yaml {
  let m : Map[String, @yaml.Yaml] = Map([])
  m["name"] = @yaml.Yaml::String(self.name)
  m["version"] = @yaml.Yaml::String(self.version)
  match self.description {
    Some(d) => m["description"] = @yaml.Yaml::String(d)
    None => ()
  }
  m["dependencies"] = self.dependencies.to_yaml()
  @yaml.Yaml::Map(m)
}

///|
/// Render the manifest to a finished `apm.yml` string, guaranteed to be safe
/// for apm's YAML loader and to end with a trailing newline.
///
/// Why the guard: apm loads generated files with PyYAML's (YAML-1.1) safe
/// loader. Any scalar that resolves to a non-string there breaks fields like
/// `ref`, which apm requires to be a non-empty string. The yaml emitter this
/// package uses already double-quotes every ambiguous YAML-1.1 form — bool-,
/// null-, int-, float-like scalars, `.inf`/`nan`, `0x`/leading-`.`/leading-`-`
/// numbers, and every timestamp form that contains a `:` (full datetimes,
/// sexagesimals). The single gap is the bare calendar-date form `YYYY-MM-DD`,
/// which the emitter leaves unquoted (its `need_quotes` has no date branch);
/// PyYAML then resolves it to `datetime.date` and apm rejects the value. So
/// `emit` validates every emitted scalar against `is_yaml11_date` and raises
/// `EmitError` (naming the field and value) rather than write a document apm
/// will reject. Everything else is already quoted correctly, so no other scalar
/// needs a guard.
///
/// `to_yaml().dump()` never terminates with a newline; `emit` appends one
/// unconditionally so the output always ends with `\n`.
///
/// # Example
/// ```mbt check
/// test {
///   let m = @apmyml.Manifest::new(
///     name="example",
///     version="0.0.1",
///     dependencies=@apmyml.Dependencies::new(apm=[
///       @apmyml.ApmDependency::new(git="github.com/o/r", path="skills/x"),
///     ]),
///   )
///   inspect(
///     m.emit(),
///     content=(
///       #|---
///       #|name: example
///       #|version: 0.0.1
///       #|dependencies:
///       #|  apm:
///       #|    - git: github.com/o/r
///       #|      path: skills/x
///       #|  mcp: []
///       #|
///     ),
///   )
/// }
/// ```
pub fn Manifest::emit(self : Self) -> String raise {
  check_scalar("name", self.name)
  check_scalar("version", self.version)
  match self.description {
    Some(d) => check_scalar("description", d)
    None => ()
  }
  for dep in self.dependencies.apm {
    check_scalar("git", dep.git)
    check_scalar("path", dep.path)
    match dep.ref_ {
      Some(r) => check_scalar("ref", r)
      None => ()
    }
  }
  for dep in self.dependencies.mcp {
    check_scalar("mcp entry", dep.name)
  }
  self.to_yaml().dump() + "\n"
}

///|
/// Raise `EmitError` if `value` is a bare YAML-1.1 calendar date (see `emit`).
fn check_scalar(field : String, value : String) -> Unit raise {
  if is_yaml11_date(value) {
    raise EmitError(
      "apmyml: field '\{field}' value '\{value}' is a bare YYYY-MM-DD date; the YAML loader resolves it to a date rather than a string. Use an unambiguous form (e.g. a tag like 'v\{value}' or a full commit SHA).",
    )
  }
}

///|
/// True iff `s` is exactly the YAML-1.1 bare calendar-date form `YYYY-MM-DD`:
/// precisely 10 characters, four digits, `-`, two digits, `-`, two digits.
///
/// The width is exact on purpose. PyYAML's date resolver matches only the
/// 4-2-2 shape; single-digit month/day forms (e.g. "2024-1-1", 8 chars) are NOT
/// dates to it, and any date carrying a time component contains a `:` (already
/// quoted by the emitter). So this narrow predicate is the exact complement of
/// what the emitter already handles.
fn is_yaml11_date(s : String) -> Bool {
  s
  is [
    '0'..='9',
    '0'..='9',
    '0'..='9',
    '0'..='9',
    '-',
    '0'..='9',
    '0'..='9',
    '-',
    '0'..='9',
    '0'..='9',
  ]
}

///|
/// Emit the dependency groups as `apm` then `mcp`. Both arrays carry their
/// actual contents; an empty group renders as `[]`.
fn Dependencies::to_yaml(self : Self) -> @yaml.Yaml {
  let m : Map[String, @yaml.Yaml] = Map([])
  m["apm"] = @yaml.Yaml::Array(self.apm.map(ApmDependency::to_yaml))
  m["mcp"] = @yaml.Yaml::Array(self.mcp.map(McpDependency::to_yaml))
  @yaml.Yaml::Map(m)
}

///|
/// Emit an apm entry as `git`, `path`, then `ref` (omitted when unpinned).
fn ApmDependency::to_yaml(self : Self) -> @yaml.Yaml {
  let m : Map[String, @yaml.Yaml] = Map([])
  m["git"] = @yaml.Yaml::String(self.git)
  m["path"] = @yaml.Yaml::String(self.path)
  match self.ref_ {
    Some(r) => m["ref"] = @yaml.Yaml::String(r)
    None => ()
  }
  @yaml.Yaml::Map(m)
}

///|
/// Emit an mcp entry as its string-form `name`.
fn McpDependency::to_yaml(self : Self) -> @yaml.Yaml {
  @yaml.Yaml::String(self.name)
}
