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
- Headless components: `@ark-ui/react` (works through `preact/compat`), for interactive widgets only.
  - Use Ark where the behavior is non-trivial to get right by hand — focus trapping, keyboard navigation, ARIA: dialogs, tabs, combobox / select / multi-select, toggle groups, popovers, menus.
  - Do not wrap static or checkbox-driven chrome in Ark: daisyUI classes on plain elements cover drawers, navbars, badges, buttons, lists, cards and tables on their own.
  - Import per component (`@ark-ui/react/dialog`), and style the parts with daisyUI classes; Ark supplies behavior, never the skin.
- Styling: `tailwindcss` v4 via `@tailwindcss/vite` plugin + `daisyui`.
- API layer: Connect RPC.
  - `@connectrpc/connect` + `@connectrpc/connect-web` clients.
  - Codegen from proto with `buf generate` + `@bufbuild/protoc-gen-es` into `src/gen/`; runtime is `@bufbuild/protobuf`.
- Markdown rendering extras (when previewing docs): `github-markdown-css`, `mermaid`, and `mathjax` (vendor MathJax assets locally with a copy script instead of loading from a CDN).
- TypeScript: `strict: true`, `noEmit` (Vite does the transpiling); typecheck with `tsc --noEmit`; also `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `isolatedModules`.
- Layout under `src/` — page-based; components used by one page live with that page, only genuinely shared UI goes under `components/`:

  ```
  src/
  ├── main.tsx                  # Mount the app, install providers
  ├── app.tsx                   # App shell and routing
  ├── index.css                 # Global styles, Tailwind/DaisyUI
  ├── pages/                    # Route-level screens
  │   ├── preview/
  │   │   ├── index.tsx         # Preview page
  │   │   ├── FileTree.tsx      # Components used only by this page
  │   │   ├── DocumentView.tsx
  │   │   └── usePreview.ts
  │   └── not-found.tsx
  ├── components/               # UI shared across pages
  │   ├── Layout.tsx
  │   ├── Header.tsx
  │   └── ui/                   # Reusable UI primitives (Ark-backed where interactive)
  │       ├── Button.tsx
  │       └── Dialog.tsx
  ├── api/
  │   ├── gen/                  # Generated protobuf code
  │   ├── client.ts             # Connect transport and clients
  │   ├── preview.ts            # Query options and mutations
  │   └── events.ts             # Server event subscriptions
  ├── signals/                  # Shared client-side state
  │   └── preferences.ts
  ├── hooks/                    # Hooks used across pages
  │   └── useMediaQuery.ts
  ├── lib/                      # Focused non-UI helpers
  │   ├── paths.ts
  │   └── paths.test.ts
  └── assets/                   # Imported images, icons, fonts
  ```
