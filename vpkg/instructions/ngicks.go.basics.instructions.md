---
description: "Go basic preference"
applyTo: ""
---

### Go basic DOs and DON'Ts

### Concurrent Go

Use:

- golang.org/x/sync/errgroup for multiple simultaneous works
- golang.org/x/sync/semaphore for (weighted) semaphore
- golang.org/x/sync/singleflight for a duplicate function call suppression mechanism
- golang.org/x/time/rate for a rate limiter

Rules:

- Do not wire `sync.WaitGroup` and `chan struct{}` by yourself as long as errgroup, semaphore and/or singleflight cover(s) the usecase.

### Types

- Do not use an anonymous struct type as a field type in a struct definition. Declare a named type instead.
  - Anonymous field types cannot be referenced by callers, have no methods, and force the full literal into every composite literal and test.

### JSON unknown fields

- Do not reject unknown fields at decode time unless the project explicitly says so.
  - Do not use v1 `(*json.Decoder).DisallowUnknownFields`.
  - Do not use v2 `json.RejectUnknownMembers(true)`.
  - Decode-time rejection stops at the first unknown name, and callers cannot choose to warn instead.
- Capture unknown fields with a v2 embedded fallback field instead: `` Unknown map[string]any `json:",embed"` ``.
- Add a `Validate` method that inspects the captured field and either rejects or warns.
  - Warn by default.
  - Reject only when the project requires strictness.

```go
type Config struct {
	Addr    string         `json:"addr"`
	Unknown map[string]any `json:",embed"`
}

func (c Config) Validate() error {
	if len(c.Unknown) > 0 {
		slog.Warn("config: unknown fields", slog.Any("keys", slices.Sorted(maps.Keys(c.Unknown))))
	}
	return nil
}
```

### Naming

- Opposing to `Go Review Comments`, do not use ALL-UPPERCASE for abbreviations in identifiers. Write `Id`, `Json`, `Http`, not `ID`, `JSON`, `HTTP`.
