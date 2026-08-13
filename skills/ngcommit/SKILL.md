---
name: ngcommit
description: "commit message convention (emoji prefix). Use whenever running `git commit`, amending a commit, or writing a commit message — even if the user does not mention any message format."
---

# ngcommit

Commit message convention.

## Format

A commit message is a subject line, optionally followed by a short body.  
The subject has no trailing period:

```
<emoji>(<scope>): brief description of change
```

- `<emoji>` — exactly one prefix emoji from the table below.
- `(<scope>)` — the scope of the change, e.g. the module / package / skill
  the change touches.
  - Omit the parentheses entirely when no meaningful scope exists:
    `📝: update readme`.
  - Comma-separate multiple scopes, no spaces:
    `📝(cc-workers,nggoal): ask user availability before getting start`.
  - If the change is cross-scope and listing every scope would be too long
    (roughly over 16 characters), omit the whole scope instead.
- Description — short, lowercase, imperative mood
  ("add", "fix", "remove" — not "added", "adds").

## Body

Most commits need no body — the subject alone is enough.  
When context matters (why, not what), add one after a blank line:

- Keep it short — around 2-3 lines.
- If the change is significant, going longer is fine.

## Emoji prefixes

Pick the one emoji matching the primary intent of the change.

| prefix | meaning                                             |
| :----- | :-------------------------------------------------- |
| ✨     | new or change of features                           |
| 🐛     | bug fixes                                           |
| 🚀     | performance optimization                            |
| 🧹     | cleaning / refactor                                 |
| 🔥     | removing stuff                                      |
| 📦     | moving files / bump dep versions                    |
| ✅     | add / change tests                                  |
| 📝     | add / change documents                              |
| 👷     | change of build / build constraint / CI/CD workflow |
| 🔖     | tag / release                                       |
| 💄     | UI and styles                                       |
| 🚧     | work in progress                                    |
| 🔊     | add / change logs                                   |

Notes on choosing:

- Skills, instructions, and other prompt files are documents — changes to
  them are 📝, even when they change agent behavior.
- Adding a new tool, hook, or skill directory from scratch is ✨.
- Only these emojis are allowed; they are chosen to render well on all
  platforms the author uses (neovim, lazygit, web browser, IDEs).
  Do not substitute other gitmoji.

## When a commit mixes intents

Prefer splitting into one commit per intent.  
If splitting is not worth it, pick the emoji for the dominant intent —
never stack multiple emojis on one subject line.

## Examples

```
✨(tool): add default targets
🐛: fix typo
📝(go-edit-cobra): forbid non-inline field in *cobra.Command
🔥: remove fragile test
👷: bump LLM stuff
📦: bump golang.org/x/sys to v0.30.0
```
