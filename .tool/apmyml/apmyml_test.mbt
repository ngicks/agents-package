///|
/// Full manifest: description present, multiple apm deps (one pinned with a
/// ref, one unpinned), empty mcp. Verifies stable key order and the object
/// entry shape.
test "full manifest with description and multiple deps" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    description="example output",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="apm-package/cc-workers",
      ),
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="skills/go-edit-cobra",
        ref_="v1.2.3",
      ),
    ]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|description: example output
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm:
      #|    - git: github.com/ngicks/agents-package
      #|      path: apm-package/cc-workers
      #|    - git: github.com/ngicks/agents-package
      #|      path: skills/go-edit-cobra
      #|      ref: v1.2.3
      #|  mcp: []
    ),
  )
}

///|
/// A single unpinned entry: `ref` key is omitted entirely when `ref_` is None.
test "entry without ref omits the key" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    description="example output",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="apm-package/cc-workers",
      ),
    ]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|description: example output
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm:
      #|    - git: github.com/ngicks/agents-package
      #|      path: apm-package/cc-workers
      #|  mcp: []
    ),
  )
}

///|
/// description = None → the `description` key is omitted from the document.
test "description None omits the key" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="apm-package/cc-workers",
      ),
    ]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm:
      #|    - git: github.com/ngicks/agents-package
      #|      path: apm-package/cc-workers
      #|  mcp: []
    ),
  )
}

///|
/// Empty apm list and empty mcp both render as empty arrays.
test "empty apm and empty mcp" {
  let manifest = @apmyml.Manifest::new(
    name="agents-package-index",
    version="0.0.1",
    dependencies=@apmyml.Dependencies::new(apm=[]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: agents-package-index
      #|version: 0.0.1
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm: []
      #|  mcp: []
    ),
  )
}

///|
/// Values that could be misread by a YAML reader: a bare `true`-like string, a
/// number-like version, and a path with characters that may force quoting.
/// Captures exactly how the emitter quotes each.
test "quoting of ambiguous scalars" {
  let manifest = @apmyml.Manifest::new(
    name="true",
    version="1.0",
    description="a: b # c",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="skills/weird: name",
        ref_="123",
      ),
    ]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: "true"
      #|version: "1.0"
      #|description: "a: b # c"
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm:
      #|    - git: github.com/ngicks/agents-package
      #|      path: "skills/weird: name"
      #|      ref: "123"
      #|  mcp: []
    ),
  )
}

///|
/// A non-empty mcp list emits its actual string-form entries (not dropped to
/// `[]`).
test "non-empty mcp entries are emitted" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    dependencies=@apmyml.Dependencies::new(apm=[], mcp=[
      @apmyml.McpDependency::new(name="server-a"),
      @apmyml.McpDependency::new(name="server-b"),
    ]),
  )
  inspect(
    manifest.to_yaml().dump(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|targets:
      #|  - claude
      #|  - codex
      #|dependencies:
      #|  apm: []
      #|  mcp:
      #|    - server-a
      #|    - server-b
    ),
  )
}

///|
/// `emit` produces the same document as `to_yaml().dump()` but with a
/// guaranteed trailing newline.
test "emit ends with a trailing newline" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="apm-package/cc-workers",
      ),
    ]),
  )
  let out = manifest.emit()
  inspect(out.has_suffix("mcp: []\n"), content="true")
  inspect(out.has_suffix("\n"), content="true")
  // dump() itself does NOT end with a newline; emit() adds exactly one.
  inspect(manifest.to_yaml().dump().has_suffix("\n"), content="false")
}

///|
/// A bare `YYYY-MM-DD` ref makes `emit` raise (it would be mis-read as a date by
/// apm's loader). The error names the offending field and value.
test "emit raises on a bare-date ref" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    dependencies=@apmyml.Dependencies::new(apm=[
      @apmyml.ApmDependency::new(
        git="github.com/ngicks/agents-package",
        path="apm-package/cc-workers",
        ref_="2024-01-01",
      ),
    ]),
  )
  let msg = try {
    let _ = manifest.emit()
    "UNEXPECTED: emit did not raise"
  } catch {
    @apmyml.EmitError(m) => m
    _ => "UNEXPECTED: wrong error type"
  }
  inspect(
    msg,
    content="apmyml: field 'ref' value '2024-01-01' is a bare YYYY-MM-DD date; the YAML loader resolves it to a date rather than a string. Use an unambiguous form (e.g. a tag like 'v2024-01-01' or a full commit SHA).",
  )
}

///|
/// `emit` does NOT raise for safe scalars: a normal tag ref, and the
/// single-digit "2024-1-1" form which PyYAML does NOT treat as a date (its
/// resolver requires exactly 4-2-2 digits).
test "emit passes on non-date-looking refs" {
  let mk = fn(r : String) {
    @apmyml.Manifest::new(
      name="example",
      version="0.0.1",
      dependencies=@apmyml.Dependencies::new(apm=[
        @apmyml.ApmDependency::new(
          git="github.com/ngicks/agents-package",
          path="apm-package/cc-workers",
          ref_=r,
        ),
      ]),
    )
  }
  let raised = fn(m : @apmyml.Manifest) -> Bool {
    try {
      let _ = m.emit()
      false
    } catch {
      _ => true
    }
  }
  // v1.2.3: normal tag, safe. 2024-1-1: single-digit m/d, NOT a YAML date.
  inspect(raised(mk("v1.2.3")), content="false")
  inspect(raised(mk("2024-1-1")), content="false")
  // exact 4-2-2: the one form apm's loader mis-reads as a date.
  inspect(raised(mk("2024-01-01")), content="true")
}

///|
/// Custom targets replace the default pair; a single entry emits as a
/// one-element list.
test "custom targets" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    targets=["codex"],
    dependencies=@apmyml.Dependencies::new(apm=[]),
  )
  inspect(
    manifest.emit(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|targets:
      #|  - codex
      #|dependencies:
      #|  apm: []
      #|  mcp: []
      #|
    ),
  )
}

///|
/// Empty targets omit the key entirely.
test "empty targets omit the key" {
  let manifest = @apmyml.Manifest::new(
    name="example",
    version="0.0.1",
    targets=[],
    dependencies=@apmyml.Dependencies::new(apm=[]),
  )
  inspect(
    manifest.emit(),
    content=(
      #|---
      #|name: example
      #|version: 0.0.1
      #|dependencies:
      #|  apm: []
      #|  mcp: []
      #|
    ),
  )
}
