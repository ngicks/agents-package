---
name: containerfile-edit
description: "Edits, creates, and reviews Containerfiles and Dockerfiles for any language. Use when writing a new Containerfile/Dockerfile, modifying an existing image build, improving build cache usage, choosing base images, hardening images, or reviewing container build changes."
---

# Containerfile Edit

Guidance for creating and editing Containerfiles (Dockerfiles), distilled from
Docker's official building best practices, adjusted with this repository's preferences.
The rules apply to Docker and Podman/Buildah alike; prefer the runtime-neutral
name Containerfile unless the project already uses Dockerfile.

## Workflow

- 1. Inspect the project first: build scripts, CI, `.dockerignore` (`.containerignore`), existing Containerfile, deployment target.
- 2. Apply the general practices below.
- 3. Read the language-specific notes under [languages/](languages/) for each language built in the image.
- 4. Build and validate: build twice to confirm warm-cache reuse;
     then change an ordinary source file without changing dependency manifests
     and confirm dependency acquisition remains cached;
     run as non-root with a read-only root filesystem.

## Language specifics

After the general pass, read `languages/<lang>.md` for the language being containerized.

- Go: [languages/go.md](languages/go.md)
- Node.js, Python, Rust: no dedicated file yet.
  For these, use whole-context `COPY` with a deliberate ignore file.
  Their conventional build workflows commonly write outputs into or below
  the source tree, while `RUN --mount=type=bind` source mounts are read-only
  by default, so such builds fail rather than modify the host tree.
  Although individual projects can redirect every output elsewhere,
  this repository deliberately standardizes on `COPY` for these ecosystems.

## Skeleton with decision points

Start from this shape; each `Decision:` comment marks a choice the sections below explain.

```dockerfile
# syntax=docker/dockerfile:1

# Decision: builder image — full toolchain, fully qualified, trusted source;
# version derived from project config, not a moving tag.
FROM docker.io/library/<toolchain>:<version> AS build

WORKDIR /app/src

# Decision: bind mount vs COPY — bind-mount source only when the build
# does not write into the tree; otherwise whole-context COPY (`COPY . .`)
# filtered by a maintained .dockerignore — never one COPY per file.
# Decision: cache mounts — one per package-manager/compiler cache;
# sharing=locked only when the tool cannot handle concurrent writers.
# Decision: secrets — always type=secret / type=ssh mounts, never ARG/ENV/COPY.
# Decision: multi-command RUN bodies are heredocs starting with `set -e`,
# never `&&`/`\` chains; a genuinely single-command RUN may stay inline.
RUN --mount=type=bind,target=/app/src \
    --mount=type=cache,target=<tool-cache-dir> \
<<EOF
    set -e
    <build commands that write required artifacts under /out>
EOF

# Decision: runtime base by runtime needs, digest-pinned:
#   scratch            -> binary needs no runtime files at all
#   distroless-family  -> needs CA certs, tzdata, or libc only
#   small distro image -> operators need a shell / package-level debugging
FROM <runtime-base>@sha256:<digest>

COPY --from=build /out/ /app/

# Decision: exec form always; fixed executable in ENTRYPOINT,
# replaceable default arguments in CMD.
# Contract: never bake USER — the image must support an arbitrary UID, and
# every consumer explicitly supplies --user under a rootless runtime; no VOLUME.
ENTRYPOINT ["/app/<entrypoint>"]
CMD ["<default-args>"]
```

## General practices

### Start every file with the syntax directive

Put `# syntax=docker/dockerfile:1` on the first line.

- Enables current BuildKit features (heredocs, cache/secret/ssh/bind mounts) while tracking the latest stable syntax.

### Use multi-stage builds

Separate the build environment from the final image.

- Build in a full toolchain image; `COPY --from` only artifacts and required runtime files into the final stage.
- Production images need no compilers, package managers, or debug tools; removing them shrinks size and attack surface.
- Name stages (`FROM ... AS build`) and share common base stages between images so they build once.
- Deleting files in a later layer does not remove bytes from earlier layers.
  Multi-stage separation is the preferred way to keep build tools and their layers
  out of the production image; never install-then-delete build tools in one image.

### Choose and pin base images

- Prefer trusted sources: Docker Official Images, Verified Publishers, or well-maintained minimal images (distroless, Alpine).
- Pick the smallest image that satisfies runtime needs; smaller images mean fewer vulnerabilities.
- Fully qualify references (`docker.io/library/golang:...`), never rely on implicit registry or namespace;
  short names resolve differently across Docker and Podman.
- Pin production base images by digest (`image:tag@sha256:...`); tags are mutable.
  - Get a digest with e.g. `podman image inspect <image>:<tag> --format '{{.Digest}}'`
    or `docker buildx imagetools inspect <image>:<tag>`.
  - A digest pins one manifest. For multi-platform builds pin the index digest,
    or keep one digest per platform when only per-platform manifests exist.
- Rebuild regularly (and with `--pull`) so tag-referenced or cached bases pick up security patches.
  - `--pull` cannot update a digest-pinned base; its security updates require
    deliberately changing the pinned digest.

### Keep the context and image lean

- Maintain `.dockerignore` (`.containerignore`) to keep VCS metadata, local artifacts, and secrets out of the build context.
  - Ignore-file portability: Docker reads only `.dockerignore`;
    Podman/Buildah prefer `.containerignore` and fall back to `.dockerignore`.
    When both files are maintained, prevent them from diverging
    (generate one from the other, or diff them in CI);
    a divergent pair builds a different context per builder.
- When copying source, maintain the ignore file and `COPY` the whole context (`COPY . .`);
  do not enumerate files or directories one `COPY` per item.
  - An enumerated list (`COPY a a`, `COPY b b`, ...) silently breaks when a new file is added:
    if no test builds the image, it becomes non-buildable or ships a stale-input bug unnoticed.
  - The only acceptable enumeration is dependency manifests (`go.mod`/`go.sum`, `package.json`, ...)
    copied first for layer-cache ordering; the source that follows is still a whole-context `COPY`.
- Install only what the application needs; no editors or debug tools "just in case".
  - For apt, update and install in one heredoc `RUN` (never `apt-get update` in its own layer;
    a cached update layer serves stale package lists forever):

```dockerfile
RUN <<EOF
    set -e
    apt-get update
    apt-get install -y --no-install-recommends <packages>
    rm -rf /var/lib/apt/lists/*
EOF
```

- When caching apt across builds instead (Debian and descendants), drop the `rm`,
  use `sharing=locked` cache mounts, and disable apt's own cache cleaning:

```dockerfile
# Decision: apt cannot handle concurrent writers -> sharing=locked;
# disable docker-clean so downloaded packages stay in the cache mount.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
    set -e
    rm -f /etc/apt/apt.conf.d/docker-clean
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    apt-get install -y --no-install-recommends <packages>
EOF
```

- Pin package versions where the ecosystem allows.
- Sort multi-line package lists alphanumerically for reviewability and to avoid duplicates.

### Optimize for the build cache

- Order instructions least- to most-frequently changing; copy dependency manifests and install dependencies before copying source.
- Use `RUN --mount=type=cache,target=...` for package-manager and compiler caches so they persist across builds without entering layers.
  - Add `sharing=locked` when the tool cannot handle concurrent writers (apt); omit it for concurrency-safe caches.
  - Store-linking package managers (pnpm, uv) hardlink/reflink from their store into install sites;
    a cache mount is a separate filesystem, so links are impossible and they silently
    fall back to full copies. Accept that: keep the cache mount and make the fallback
    explicit (`UV_LINK_MODE=copy` for uv, `package-import-method=copy` for pnpm)
    so the tools stop warning. The cost is build-time only.
  - Link-based dedup cannot shrink the image either way: the store in a cache mount
    never enters a layer, so nothing in the image can link into it.
    Get size wins from multi-stage builds shipping only installed trees.
    Only when many packages in one image share most dependencies, consider a
    deliberately baked shared-store layer (hardlinks are preserved when store and
    install sites land in the same layer) — it replaces the cache mount and costs
    cold-build speed; it does not compose with it.
- Use `RUN --mount=type=bind` to read build inputs without a `COPY` layer, only when the build does not write into the mount.
- Write every multi-command `RUN` body as a heredoc (`RUN <<EOF ... EOF`), one command per line.
  Never concatenate commands with `&&` and trailing `\`; those chains are tedious to read,
  diff, and edit, and a missed connector silently drops a command.
  - Docker's page suggests sorted `&&` chains; this repository supersedes that with heredocs
    (sorting package lists alphanumerically still applies).
  - Start every heredoc body with `set -e`. Both BuildKit and Buildah pass the body verbatim
    to plain `sh -c` (no errexit), so without it only the last line's exit status counts
    and mid-script failures pass silently.
  - Formatting: when `--mount` flags occupy continuation lines, put `<<EOF` alone at
    column 0 with no leading spaces; a plain `RUN <<EOF` keeps the heredoc on the `RUN` line.
    Indent the body by 4 spaces; the closing `EOF` sits at column 0.
- When a heredoc uses a shell pipe, also set `set -o pipefail` (bash/ash, not POSIX sh;
  use a `#!/bin/bash` shebang or exec-form shell if needed) so failures before
  the last pipe stage fail the build.

### Never let credentials touch layers

- Pass secrets via `RUN --mount=type=secret` and SSH access via `RUN --mount=type=ssh`.
- Never put credentials in `ARG`, `ENV`, `COPY`, or any layer; build args and env values persist in image history.
- When a git host offers only HTTPS (no SSH), tokens still travel only through secret mounts:
  - `.netrc` as a secret mount (`--mount=type=secret,id=netrc,target=/root/.netrc`);
    honored by git, go, curl, and pip alike.
  - Or a git credential helper reading a secret-exposed env var
    (`--mount=type=secret,id=git_token,env=GIT_TOKEN` plus a helper that echoes it);
    the git config baked this way contains no secret, only the mounted env does.
  - Never `credential.helper store` and never `url."https://user:<token>@host".insteadOf`;
    both write the token into build-stage layers, which leak through cache exports
    even when the final stage is clean.
  - An internal package/module proxy, or vendored dependencies, sidesteps
    build-time git credentials entirely.
- Unsetting an `ENV` in a later instruction does not remove it from history;
  export-use-unset within one `RUN` if a value must not persist.

### Corporate proxy and custom CA

- Do not mount the CA bundle over the package-managed system bundle
  (`/etc/ssl/certs/ca-certificates.crt`); mount it as a secret at a neutral path
  and point trust env vars at the mount target (`SSL_CERT_FILE` generally;
  language-specific ones such as `NODE_EXTRA_CA_CERTS` or `DENO_CERT` where the tool needs them):

```dockerfile
# Decision: corporate CA as a secret mount at a neutral path,
# never baked into a layer and never shadowing the system bundle.
RUN --mount=type=secret,id=corporate-ca,target=/run/secrets/corporate-ca.pem \
    SSL_CERT_FILE=/run/secrets/corporate-ca.pem \
    <command>
```

- When both public and corporate roots are needed, construct or supply a
  deliberately combined bundle and point `SSL_CERT_FILE` at that.
- Pass proxy values (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` and lowercase variants)
  without baking credentials: secret mounts where the runtime supports it;
  if a runtime can only take build args, strip credentials
  (e.g. a credential-stripping forward proxy) before accepting that.

### Build for multiple platforms deliberately

- Pass the target platform to the build and let multi-platform base image indexes
  select the matching image.
- Cross-compile with the language toolchain where possible: keep the build stage on
  `--platform=$BUILDPLATFORM` and derive the target from the `TARGETOS`/`TARGETARCH` build args.
- Use QEMU emulation (`qemu-user-static`, `binfmt_misc`) only when a build step must
  execute target-architecture binaries; expect it to be slow.
- Per-architecture digests differ (see base pinning above); make outputs unambiguous
  with arch-suffixed tags or a published manifest list covering all platforms.

### Per-instruction rules

- `FROM`: see base image rules above.
- `RUN`: heredocs, cache mounts, pipefail as above.
- `CMD` / `ENTRYPOINT`: always exec form (JSON array); shell form breaks signal delivery.
  - Fixed executable in `ENTRYPOINT`, replaceable default arguments in `CMD`.
  - If a wrapper script is unavoidable, end it with `exec "$@"` so the application is PID 1.
- `COPY` vs `ADD`: prefer `COPY`; use `ADD` only for remote artifacts, together with `--checksum`.
- `WORKDIR`: absolute paths only; never `RUN cd ... && ...` chains.
- `ENV`: for `PATH` and values the runtime genuinely needs; centralize version numbers when they repeat.
- `EXPOSE`: declare the conventional listening port as documentation.
- `LABEL`: add OCI labels (source, revision, licenses) when the project publishes images.
- `USER`: never bake one — this is a deployment contract, not an omission to fix.
  - The image must support an arbitrary UID, and every consumer must explicitly
    supply `--user` under a rootless runtime for host UID/GID mapping.
  - Docker's page recommends baking a non-root `USER`; this repository supersedes that.
    Do not "harden" an image by adding `USER`, and remove a baked `USER` when reviewing.
  - Either way: no path may require root at run time, and never use `sudo` in containers.
- `VOLUME`: avoid it in the image, contrary to Docker's page.
  - It cannot be undone downstream and copies pre-existing content unpredictably; declare mounts at deployment time.
- `ONBUILD`: avoid unless deliberately authoring an extendable base image; tag such images distinctly.

### Keep the Containerfile portable across builders

Docker (BuildKit) and Podman/Buildah support the features above at slightly different levels;
a Containerfile that only ever ran on one builder is not verified portable.

- `RUN --mount=type=secret,...,env=VAR` (secret as env var) is supported by current
  Docker and current Buildah alike; older Buildah releases lacked it.
  When targeting an old deployed builder, verify support there first
  (fallbacks: `target=` file mounts, or credential-stripped `--build-arg` for proxy-style values).
- `RUN --mount=type=ssh`: Buildah closes each SSH agent connection after a hardcoded 2 seconds
  (`pkg/sshagent/sshagent.go`, `Serve`; present as of v1.45.0), so PIN or passphrase prompts
  (pinentry) cannot complete inside that window.
  Before starting the build, force every key the build may use to perform a local signing
  operation (`ssh-add -T <public-key>`) so the confirmation completes outside
  Buildah's short SSH-agent connection window;
  `ssh-add -T` tests that the agent-held private key can sign, not just that an identity exists.
  Newer Buildah may fix this; check the current source before relying on the caveat.
- The `# syntax=docker/dockerfile:1` directive is honored by BuildKit; Buildah ignores it
  and supports its own subset of the syntax natively. Keep the directive, but do not assume
  it upgrades Buildah's feature set.
- Short image names resolve differently: Docker completes to Docker Hub while Podman prompts
  for a registry; fully qualified references avoid both behaviors.

When a feature only works on one builder, say so in the Containerfile (comment) or docs
instead of presenting the build as portable.

### Design for ephemeral, single-concern containers

- One concern per container; containers must be destroyable and replaceable without manual setup.
- Persist state only in explicitly mounted volumes; run with a read-only root filesystem in production.
- Build, tag, and test images in CI on every change.

## Review checklist

- Syntax directive present; every image reference fully qualified; production bases digest-pinned.
- Final stage contains only runtime requirements.
- Source copied as whole context plus ignore file, not as an enumerated `COPY` list
  (dependency manifests for cache ordering are the only exception).
- Cache mounts on package-manager and compiler caches, with correct `sharing` mode.
- Multiline `RUN` uses heredocs, never `&&`/`\` chains; every heredoc starts with `set -e`; pipes use `pipefail`.
- No credential can reach layers, history, logs, or cache exports.
- `ENTRYPOINT`/`CMD` in exec form; image works as non-root with read-only root filesystem.
- No baked `USER` (deployment contract: arbitrary UID plus explicit runtime `--user`); no `VOLUME`.
- Language-specific notes applied for every language in the build.
- Builder portability verified, not assumed: every BuildKit feature used
  (secret `env=` mounts, ssh mounts, syntax-directive-gated features, short names)
  checked against both Docker and Podman/Buildah support levels,
  and any builder-specific compromise documented.
