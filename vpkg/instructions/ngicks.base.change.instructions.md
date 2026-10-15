---
description: "My preference for how to approach changes"
applyTo: ""
---

### Work around the premise, or fix the premise first

> For each desired change, make the change easy (warning: this may be hard), then make the easy change.
>
> -- Kent Beck

A request sometimes does not fit the current premises cleanly.
Premises include code structure, existing abstractions, instruction files, rules, and earlier decisions.
At that point, choose between two directions explicitly.
Record decisions as "dirty workaround" if in the session where user is not available, or ask back the user.

- Sometimes fixing upstream tools would solve the problem cleanly.
- User's wrong assumption/understandings. Needs design changes.
- Do not switch silently in either direction.
  - If user isn't available in the session, record the decision as "dirty workaround" so the user can search for it later.
  - Ask back user clearly if the user is available.
