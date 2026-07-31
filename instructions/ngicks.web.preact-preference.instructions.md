---
description: "Preferred stack for Preact SPA frontends"
applyTo: "**/*.{ts,tsx,css,html}"
---

### Preact SPA stack preference

When building an SPA frontend, prefer the following stack (as used in crabswarm's `web/`):

- Package manager: `pnpm` (with `pnpm-workspace.yaml`; pin risky packages via `minimumReleaseAgeExclude` when needed).
- Build: `vite` with `@preact/preset-vite`.
  - Dev server proxies API paths to the locally running backend so frontend iteration needs no backend rebuild.
  - `vite build` emits into `dist/`; when the SPA is served by a Go binary, embed it with `//go:embed all:dist`.
- UI framework: `preact` + `preact-iso` (routing).
  - Alias `react` / `react-dom` / `react/jsx-runtime` to `preact/compat` in `tsconfig.json` `paths` so React-only libraries work.
  - `jsx: "react-jsx"` with `jsxImportSource: "preact"`.
- State:
  - Client state: `@preact/signals`.
  - Server state / data fetching: `@tanstack/preact-query`.
- Headless components: `@ark-ui/react` (works through `preact/compat`).
- Styling: `tailwindcss` v4 via `@tailwindcss/vite` plugin + `daisyui`.
- API layer: Connect RPC.
  - `@connectrpc/connect` + `@connectrpc/connect-web` clients.
  - Codegen from proto with `buf generate` + `@bufbuild/protoc-gen-es` into `src/gen/`; runtime is `@bufbuild/protobuf`.
- Markdown rendering extras (when previewing docs): `github-markdown-css`, `mermaid`, and `mathjax` (vendor MathJax assets locally with a copy script instead of loading from a CDN).
- TypeScript: `strict: true`, `noEmit` (Vite does the transpiling); typecheck with `tsc --noEmit`; also `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `isolatedModules`.
- Suggested layout under `src/`: `api/` (clients, queries, events), `components/`, `signals/` (UI state), `gen/` (generated code), `routes.tsx`, `main.tsx`, `index.css`.
