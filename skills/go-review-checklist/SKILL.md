---
name: go-review-checklist
description: "Use this to review your change if you have edited Go code."
---

# Go Review Checklist

Use this checklist to find incorrect or half-baked implementations, or not-matching my personal preference.

## General Problem

- Do long-blocking functions take `ctx context.Context` as the first argument? If not, add one.
- Is your file kept small? Keep it under 300 LoC.
  - If a struct type of many methods is defined in a single file and getting longer, then split file to a Exported method per a file.
  - Put unexported methods to file where more corresponding exported methods
  - If splitting files makes no sense, e.g. when there's no semantic / meaning break point in the source file, keep it long.

## Preference

- Opposing to `Go Review Comments`, do not use ALL-UPPERCASE for abbreviations. e.g. Id instead of ID.
