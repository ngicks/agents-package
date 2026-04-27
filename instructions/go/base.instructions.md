---
description: "Up to data basic Go rule"
applyTo: "**/*.go"
---

## Go 1.26 or above

- Use `new(<expr>)` to create a pointer of primitive types(e.g. `new("some string")`, `new(true)`).
  - DO NOT define a helper for pointer types.
