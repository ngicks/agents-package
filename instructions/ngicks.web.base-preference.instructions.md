---
description: "Base preference for web (frontend) projects"
applyTo: "**/*.{ts,tsx,js,jsx,mjs,css,html}"
---

### Web base preference

- Use `pnpm` as the package manager for node.js-based web projects.
  - NEVER use `npm` or `yarn` to install / manage dependencies.
  - If `pnpm` is missing from the environment, do NOT silently fall back to another package manager; ask the user whether to continue or stop.
