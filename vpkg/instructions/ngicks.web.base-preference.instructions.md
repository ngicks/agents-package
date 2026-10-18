---
description: "Base preference for web (frontend) projects"
applyTo: ""
---

### Package manager

- Use `pnpm` as the package manager for node.js-based web projects.
  - NEVER use `npm` or `yarn` to install / manage dependencies.
  - If `pnpm` is missing from the environment, do NOT silently fall back to another package manager; ask the user whether to continue or stop.

### Import path aliases

- `@` → `src/` when the whole source lives under `src/` (the de facto convention: Vue CLI, Nuxt, Next.js templates, shadcn/ui).
  - This is a bundler-level alias: declare it in BOTH `tsconfig.json` (`paths`) and the bundler (e.g. Vite `resolve.alias`), and keep the two in sync.
- `#` → project root, via Node.js subpath imports (`imports` field in `package.json`; the leading `#` is required by the spec).
  - Define it ONLY in `package.json` — Node, TypeScript (`moduleResolution: "bundler"` / `"node16"`), and Vite all read the `imports` field directly, so no `paths` or `resolve.alias` entry is needed. It also resolves natively in Node, so scripts / SSR / tests running outside the bundler work unchanged.
  - The bare keys `#` and `#/` are forbidden by the spec; use a pattern like `"#*": "./*"` (so `#scripts/x` → `./scripts/x`).
- Do NOT use `~` — it has conflicting historical meaning (webpack-era CSS/Sass `~` meant `node_modules`).

### Playwright

- The environment sets `PLAYWRIGHT_BROWSERS_PATH` to a persistent browser cache shared by every project.
  - Do not override it, unset it, or set it per project.
  - Check with `echo "$PLAYWRIGHT_BROWSERS_PATH"`; if it is empty, ask the user before downloading anything.
- Playwright downloads browsers into that cache by itself. Install them through the project's own dependency:
  - Pin `@playwright/test` (or `playwright`) in `package.json`, then run `pnpm exec playwright install chromium`.
  - Each Playwright version needs its own browser revision directory (e.g. `chromium-1234`). After bumping the dependency, run the install command again; the cache keeps old revisions, so other projects keep working.
  - Install only `chromium` unless the user asks for `firefox` or `webkit`.
- NEVER run `playwright install-deps`.
  - System libraries come from the environment, not from apt. `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true` is set for that reason.
  - If a browser fails to launch over a missing shared library, report it to the user instead of installing packages.
