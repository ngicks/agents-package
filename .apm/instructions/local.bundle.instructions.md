---
description: "Layout rules for the bundles under bundle/"
applyTo: "bundle/**"
---

### bundle layout

Each directory under `bundle/` holds one hand-curated `apm.yml` that lists units from `pkg/` and `vpkg/`.
A bundle serves two uses with the same file.

- Consumers copy it in as their own `apm.yml`, then edit `name`, `targets`, and the dependency list.
- Consumers depend on it (`ngicks/agents-package/bundle/<name>`) to install every listed unit in one shot.

### Rules

- Write every dependency as a full repository path (`ngicks/agents-package/vpkg/skills/<name>`).
  - Relative or local paths break once the file is copied elsewhere.
- Do not add `.apm/` or any primitive to a bundle.
  - A copied-in bundle would lose it.
- Do not depend on another bundle.
  - Copying one in would pull the other in without the reader seeing its list.
- Do not list a `vpkg/` unit that a listed `pkg/` package already ships.
  - apm would install the same primitive twice.
- Leave out `vpkg/mods/`.
  - Mods are user-scope installs (`apm install -g`), and a bundle is a project dependency.

### Verify before shipping

A bundle resolves its dependencies from GitHub, so it only verifies after the units it lists are pushed.

```bash
mkdir -p /tmp/apm-consumer && cd /tmp/apm-consumer
cp /abs/path/to/agents-package/main/bundle/<name>/apm.yml apm.yml
apm install --update -t claude
```
