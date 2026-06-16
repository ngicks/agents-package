# `pkg/{{NAME}}/config.go` source template

The service-side configuration source: `Config` + `DefaultConfig`, the exported `PartialConfig` + `Apply`, the isolated `unmarshalConfigFile`, and `LoadConfig`.

The model these implement (layers, merge rules, precedence, path resolution, flag overlay) is documented in [configuration.md](configuration.md) — read it first.

These are templates — **strictly follow** the order of elements; do **NOT** reorder.

## Contents

- [`pkg/{{NAME}}/config.go` (JSON-only default)](#pkgnameconfiggo-always-present)
- [YAML support (YAML-only or both formats)](#yaml-support-yaml-only-or-both-formats)

## `pkg/{{NAME}}/config.go` (always present)

The service configuration.

Assembles **defaults < file < env** through one overlay primitive, `PartialConfig.Apply`; the `./cmd` run function overlays explicitly-set flags on top (see [Service package & configuration](configuration.md) and [Merge semantics](configuration.md#merge-semantics-partialconfigapply) for the rules).

Replace the example fields with the real config.

It is a **single** `config.go` — the env layer is just the package-level `envOptions` plus a direct `env.ParseWithOptions` call inside `LoadConfig`.

The example deliberately exercises all four merge kinds: a **scalar** (`Addr`, `Port`), a **nested sub-config** (`Server` — deep-merged; note its `TLS bool` defaults `true`, a zero-meaningful field the pointer mirror handles for free), a **map** (`Labels` — deep-merged by key), and a **slice** (`Hosts` — overwritten wholesale).

```go
package {{NAME}}

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/caarlos0/env/v11"
)

// Config is the materialized configuration the service consumes, after every
// layer (defaults < file < env < flags) is applied. Its fields are value types
// (the merged config is always concrete) and carry both json and yaml tags so the
// `config` subcommand can marshal it and a project can adopt either file format
// without touching fields. The file is NOT decoded into Config — PartialConfig is
// the decode target; Config only ever holds a fully-merged result.
type Config struct {
	Addr   string            `json:"addr" yaml:"addr"`
	Port   int               `json:"port" yaml:"port"`
	Server ServerConfig      `json:"server" yaml:"server"` // nested sub-config: deep-merged
	Labels map[string]string `json:"labels" yaml:"labels"` // map: deep-merged (key union)
	Hosts  []string          `json:"hosts" yaml:"hosts"`   // slice: overwritten wholesale
}

// ServerConfig is a sub-config. TLS defaults true, so its zero value (false) is a
// meaningful override — handled for free because PartialServerConfig.TLS is a
// pointer (nil = unset, &false = explicit off).
type ServerConfig struct {
	TLS     bool `json:"tls" yaml:"tls"`
	Timeout int  `json:"timeout" yaml:"timeout"`
}

// DefaultConfig is the lowest-precedence layer. Initialize maps and sub-configs
// here so later layers deep-merge into a populated base.
func DefaultConfig() Config {
	return Config{
		Addr:   "0.0.0.0",
		Port:   8080,
		Server: ServerConfig{TLS: true, Timeout: 30},
		Labels: map[string]string{"managed-by": "{{NAME}}"},
		Hosts:  nil,
	}
}

// PartialConfig is the exported sparse mirror of Config's serialized shape (the
// same keys): a nil/zero field means "absent, leave the lower layer"; a set field
// is an explicit value, including an explicit zero. It is the decode target for
// the config file (JSON or YAML) AND the struct LoadConfig fills via
// caarlos0/env, so file and env merge through one method, Apply. Exported so other
// code can build or inspect partial overrides.
//
// Carries three tag sets, kept in sync with Config field-for-field: json + yaml
// for the file decode, and env / envPrefix for caarlos0/env. Field kinds:
//   - scalar:        *T (nil = absent; *false / *0 = explicit zero). env:"NAME".
//   - nested struct: a VALUE PartialXxx (not a pointer) with its own Apply, and
//                    envPrefix:"NAME_". caarlos0/env recurses into value nested
//                    structs but leaves nil pointer-structs unset; a zero value
//                    sub-partial still means "nothing set" for the file too.
//   - map / slice:   plain map/slice (nil = absent). env:"NAME"; caarlos0/env
//                    parses "k:v,k2:v2" / "a,b,c" natively.
// The {{NAME_UPPER}}_ prefix is applied once via envOptions, so the tags hold
// only the bare names (ADDR -> {{NAME_UPPER}}_ADDR, SERVER_ + TLS -> ..._SERVER_TLS).
//
// JSON tags use ",omitzero" (Go 1.24+): when a PartialConfig is marshaled back out
// (e.g. to write a sparse override file or a diff), omitzero drops nil/absent
// fields but preserves an EXPLICIT zero — including a non-nil empty []/{}, which
// the merge rules treat as "present, set to empty". (Tags affect only marshaling,
// never decoding, so this is free on the load path.)
//
// YAML has no omitzero, so the yaml tags use ",omitempty" — which DOES drop a
// non-nil empty []/{} on marshal. Decoding is unaffected (the normal path); only a
// YAML round-trip of a partial loses the explicit-empty signal. Marshal partials
// to JSON when that distinction matters.
//
//nolint:lll // triple json/yaml/env tags; one field per line, never wrap tags
type PartialConfig struct {
	Addr   *string             `json:"addr,omitzero" yaml:"addr,omitempty" env:"ADDR"`
	Port   *int                `json:"port,omitzero" yaml:"port,omitempty" env:"PORT"`
	Server PartialServerConfig `json:"server,omitzero" yaml:"server,omitempty" envPrefix:"SERVER_"`
	Labels map[string]string   `json:"labels,omitzero" yaml:"labels,omitempty" env:"LABELS"`
	Hosts  []string            `json:"hosts,omitzero" yaml:"hosts,omitempty" env:"HOSTS"`
}

//nolint:lll // triple json/yaml/env tags; one field per line, never wrap tags
type PartialServerConfig struct {
	TLS     *bool `json:"tls,omitzero" yaml:"tls,omitempty" env:"TLS"`
	Timeout *int  `json:"timeout,omitzero" yaml:"timeout,omitempty" env:"TIMEOUT"`
}

// Apply overlays p's present fields onto base and returns the merged Config.
// Merge rules by field kind:
//   - scalar:        non-nil pointer overwrites (explicit zero included).
//   - nested struct: deep-merged via the sub-partial's Apply — always called; a
//                    zero sub-partial (all fields nil) merges nothing.
//   - map:           deep-merged key by key into a fresh map (incoming wins;
//                    base-only keys kept; base not mutated).
//   - slice/array:   non-nil incoming slice overwrites wholesale (nil = leave base).
func (p PartialConfig) Apply(base Config) Config {
	if p.Addr != nil {
		base.Addr = *p.Addr
	}
	if p.Port != nil {
		base.Port = *p.Port
	}
	base.Server = p.Server.Apply(base.Server)
	if p.Labels != nil {
		merged := make(map[string]string, len(base.Labels)+len(p.Labels))
		for k, v := range base.Labels {
			merged[k] = v
		}
		for k, v := range p.Labels {
			merged[k] = v
		}
		base.Labels = merged
	}
	if p.Hosts != nil {
		base.Hosts = p.Hosts
	}
	return base
}

func (p PartialServerConfig) Apply(base ServerConfig) ServerConfig {
	if p.TLS != nil {
		base.TLS = *p.TLS
	}
	if p.Timeout != nil {
		base.Timeout = *p.Timeout
	}
	return base
}

// envOptions configures caarlos0/env for the env layer in LoadConfig. The
// variable names live in the env: / envPrefix: tags on PartialConfig; the
// {{NAME_UPPER}}_ prefix is applied here, yielding {{NAME_UPPER}}_ADDR,
// {{NAME_UPPER}}_SERVER_TLS, {{NAME_UPPER}}_LABELS, etc.
var envOptions = env.Options{Prefix: "{{NAME_UPPER}}_"}

// LoadConfig assembles defaults < config file < environment through Apply. The
// ./cmd layer applies explicitly-set flags on top (flags win). flagPath is the
// --config value ("" when the flag is unset). Rename to config.Load in a sub-package.
//
// The env layer fills a PartialConfig with caarlos0/env: a scalar/slice/map is
// set (non-nil) only when its variable is present; absent ones stay nil so Apply
// leaves the lower layer untouched. caarlos0/env parses slices ("a,b,c") and
// maps ("k:v,k2:v2") natively, and recurses into the value nested sub-config via
// envPrefix. ParseWithOptions errors when a present value fails to parse (e.g. a
// non-numeric PORT) — a hard error that aborts startup. t.Setenv + LoadConfig
// keeps the layer unit-testable.
func LoadConfig(flagPath string) (Config, error) {
	cfg := DefaultConfig()

	path, err := configPath(flagPath)
	if err != nil {
		return cfg, err
	}
	filePartial, err := unmarshalConfigFile(path)
	if err != nil {
		return cfg, err
	}
	cfg = filePartial.Apply(cfg)

	var envPartial PartialConfig
	if err := env.ParseWithOptions(&envPartial, envOptions); err != nil {
		return cfg, err
	}
	cfg = envPartial.Apply(cfg)

	return cfg, nil
}

// unmarshalConfigFile only reads + decodes; it never merges. It decodes into a
// fresh zero PartialConfig (all nil) and returns the zero value when the file
// does not exist. A non-ENOENT read error or a JSON parse error aborts.
//
// Decoding into a zero value — never a defaults-populated struct — sidesteps the
// v1 encoding/json merge edge cases that decoding into a populated struct hits;
// Apply does the merge afterward.
func unmarshalConfigFile(path string) (PartialConfig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return PartialConfig{}, nil
		}
		return PartialConfig{}, fmt.Errorf("read config %q: %w", path, err)
	}
	var p PartialConfig
	if err := json.Unmarshal(b, &p); err != nil {
		return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
	}
	return p, nil
}

// envConfVar names the config-file-path override. It is the one env var read by
// hand (the file path is needed before parsing, and is not a Config field); every
// other variable lives in PartialConfig's env tags. MixedCaps, so no naming-lint
// directive is needed.
const envConfVar = "{{NAME_UPPER}}_CONF"

// configPath resolves the file path: --config (flagPath), else $envConfVar, else
// os.UserConfigDir()/{{NAME}}/config.json.
func configPath(flagPath string) (string, error) {
	if flagPath != "" {
		return flagPath, nil
	}
	if p, ok := os.LookupEnv(envConfVar); ok {
		return p, nil
	}
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "{{NAME}}", "config.json"), nil
}
```

- `Config` and `PartialConfig` mirror each other and carry the **same** json **and** yaml keys (`Config` is what the `config` subcommand marshals; `PartialConfig` is the file/env decode target).

  `PartialConfig` additionally carries `env:` / `envPrefix:` tags for caarlos0/env.

  Keep all of them — and each nested `Sub` / `PartialSub` pair — in sync.

  The json/yaml tags are present even in a JSON-only project, so adopting YAML later is an import + `configPath`/`unmarshalConfigFile` change, never a field change.

- **Spell serialized keys in `snake_case`** (multi-word: `max_conns`, not `maxConns`/`MaxConns`) in both the json and yaml tags — idiomatic across YAML and TOML, and a clean match to the `SCREAMING_SNAKE` env names.

  The example fields above are single-word, so they are simply lowercase. See [Key naming in configuration.md](configuration.md#config-file-format-json-yaml-or-both).

- This template is the **JSON-only** file default (no YAML dependency).

  For YAML-only or both-format projects, swap `unmarshalConfigFile`/`configPath` and `go.mod` per the [YAML support block](#yaml-support-yaml-only-or-both-formats) below.

  The env layer (caarlos0/env) is unchanged across all file formats.
- **caarlos0/env handles maps and slices from env natively** — `{{NAME_UPPER}}_LABELS=k:v,k2:v2` and `{{NAME_UPPER}}_HOSTS=a,b,c` (override the separators with `envSeparator` / `envKeyValSeparator` tags).

  A field with **no** `env`/`envPrefix` tag is simply not env-settable (file-only).

- **Nested sub-configs are VALUE structs, not pointers.** caarlos0/env populates a value nested struct (via `envPrefix`) but leaves a nil pointer-struct unset, so a pointer here would silently never read its env vars.

  The value form costs nothing: a zero sub-partial merges nothing in `Apply` and is omitted on marshal (`omitzero` drops a zero struct; YAML `omitempty` drops a struct whose public fields are all zero).

- **Apply is pure w.r.t. its base**: it returns a new `Config` and allocates a fresh map rather than mutating the base's map.

  That makes `PartialConfig` + `Apply` reusable outside `LoadConfig` (tests, programmatic overrides) without aliasing surprises.

## YAML support (YAML-only or both formats)

The fields already carry `yaml:` tags.

To accept YAML, add a YAML decoder and make `unmarshalConfigFile` pick by extension; for _both_ mode, make `configPath` probe YAML before JSON (YAML wins; one file only — never blended).

Add the dependency with `go get go.yaml.in/yaml/v4@v4.0.0-rc.5` (pinned — v4 is pre-release; check for a newer rc/GA first) — or `go.yaml.in/yaml/v3` / `github.com/goccy/go-yaml`, for which the `yaml.Unmarshal` call is identical.

```go
import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"go.yaml.in/yaml/v4"
)

type fileFormat int

const (
	formatJSON fileFormat = iota
	formatYAML
)

// detectFormat picks a decoder from the file extension; anything that is not a
// known YAML extension decodes as JSON (the default).
func detectFormat(path string) fileFormat {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".yaml", ".yml":
		return formatYAML
	default:
		return formatJSON
	}
}

// unmarshalConfigFile reads + decodes into a fresh zero PartialConfig, choosing
// the decoder by extension. Absent file -> zero value. Never merges.
func unmarshalConfigFile(path string) (PartialConfig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return PartialConfig{}, nil
		}
		return PartialConfig{}, fmt.Errorf("read config %q: %w", path, err)
	}
	var p PartialConfig
	switch detectFormat(path) {
	case formatYAML:
		if err := yaml.Unmarshal(b, &p); err != nil {
			return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
		}
	default:
		if err := json.Unmarshal(b, &p); err != nil {
			return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
		}
	}
	return p, nil
}

// configPath (both mode): --config / $envConfVar win as explicit paths (format by
// extension); otherwise probe the default dir YAML-first and return the first that
// exists. YAML takes precedence over JSON; only that one file is loaded.
func configPath(flagPath string) (string, error) {
	if flagPath != "" {
		return flagPath, nil
	}
	if p, ok := os.LookupEnv(envConfVar); ok {
		return p, nil
	}
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	base := filepath.Join(dir, "{{NAME}}")
	for _, name := range []string{"config.yaml", "config.yml", "config.json"} {
		p := filepath.Join(base, name)
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return filepath.Join(base, "config.json"), nil // absent -> defaults
}
```

For **YAML-only**, drop the `encoding/json` branch (and import) and the `config.json` probe entry; decode with `yaml.Unmarshal` unconditionally and default the path to `config.yaml`.

For **both**, keep the switch as shown.
