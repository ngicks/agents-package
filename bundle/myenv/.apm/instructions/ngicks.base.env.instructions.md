---
description: "Basic instructions for my env"
applyTo: ""
---

### Base enviroment

- You are basically in a restricted enviroment: some commands may fail and some special files may not be present (e.g. `/dev/kvm`).

### Tool choice

- Do not assume `perl` is installed in the environment and do not try to install it.
- Do not use `apm` directly in this environment. Use `apm-bump` or `apm-install` shell function provided from loginscript. Use it at bare root where `.bare` exists.
