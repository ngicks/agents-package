---
description: "Base preference for web (frontend) projects"
applyTo: "**/*.{ts,tsx,js,jsx,mjs,css,html}"
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

- Browsers and their deps are provided through nix, NOT downloaded by Playwright itself.
- The environment sets `PLAYWRIGHT_BROWSERS_PATH` to a nix store path; the Playwright library version (npm `@playwright/test` / `playwright`, or `playwright-go`) MUST match the version those nix-provided browsers were built for — browser revision directories (e.g. `chromium-1228`) are version-specific and a mismatched library will not find them.
- NEVER run `playwright install` / `playwright install-deps`, and NEVER bump the Playwright dependency independently. When a newer Playwright is needed, update the nix side first (or ask the user), then align the dependency to it.
