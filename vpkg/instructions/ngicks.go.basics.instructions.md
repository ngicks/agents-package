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

### Naming

- Opposing to `Go Review Comments`, do not use ALL-UPPERCASE for abbreviations in identifiers. Write `Id`, `Json`, `Http`, not `ID`, `JSON`, `HTTP`.
