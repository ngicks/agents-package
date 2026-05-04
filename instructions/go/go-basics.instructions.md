---
description: "Go basic preference"
applyTo: "**/*.go"
---

### Go basic DOs and DON'Ts

Use:

- golang.org/x/sync/errgroup for multiple simultaneous works
- golang.org/x/sync/semaphore for (weighted) semaphore
- golang.org/x/sync/singleflight for a duplicate function call suppression mechanism
- golang.org/x/time/rate for a rate limiter

Rules:

- Do not wire `sync.WaitGroup` and `chan struct{}` by yourself as long as errgroup, semaphore and/or singleflight cover(s) the usecase.
