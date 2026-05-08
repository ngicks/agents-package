---
name: go-review-checklist
description: "Use this to review your change if you have edited Go code."
---

# Go Review Checklist

Use this checklist to find incorrect or half-baked implementations.

## List

- Do long-blocking functions take `ctx context.Context` as the first argument? If not, add one.
- Is your file kept small? Keep it under 300 LoC.
  - If a struct type of many methods is defined in a single file and getting longer, then split file to a method per a file.
