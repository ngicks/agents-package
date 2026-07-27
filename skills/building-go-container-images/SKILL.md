---
name: building-go-container-images
description: Builds and reviews production container images for Go applications using Podman, Docker, Containerfile, or Dockerfile. Use when containerizing a Go program, editing a Go image build, improving BuildKit caching, handling private Go modules or corporate proxies, choosing CGO or a runtime base, adding multi-platform builds, or hardening how a Go container runs.
---

# Building Go Container Images

Build small, reproducible Go images without leaking credentials or coupling the
result to one container runtime.

## Inspect before editing

- Read `go.mod`, including the `go` and optional `toolchain` directives.
- Locate every main package and confirm which package the image must build.
- Check for CGO dependencies, embedded assets, generated code, Git LFS content,
  private modules, and runtime files such as CA certificates or timezone data.
- Inspect the existing Containerfile (or Dockerfile), build scripts,
  `.dockerignore`, CI workflow, and deployment platform.
- Preserve project conventions unless they conflict with correctness or
  security.

Do not assume a pure-Go static binary. Confirm it from dependencies and a real
build.

## Choose the build shape

Use a multi-stage build:

- Build in a fully qualified Go image such as
  `docker.io/library/golang:<version>-<distro>`.
- Copy only the executable and required runtime files into the final stage.
- Choose the final image from runtime needs:
  - Use `scratch` only when the binary needs no certificates, timezone data,
    shell, libc, or other files.
  - Use a pinned distroless or similarly minimal image when those runtime files
    are needed.
  - Use a small distribution image when operators need a shell or package-level
    debugging.
- Set `CGO_ENABLED=0` only when the application and its dependencies do not need
  CGO. When CGO is required, keep the required ABI and shared libraries in the
  runtime image.

Deleting files in a later layer does not remove bytes from earlier layers.
Keep build tools out of the final stage instead of installing and deleting them.

## Make the build portable and cache-friendly

- Put `# syntax=docker/dockerfile:1` at the start when using BuildKit syntax.
- Write `RUN` bodies as heredocs. Prefer readable command sequences under
  `<<EOF` over backslash-heavy shell chains.
- Fully qualify image references. Do not rely on implicit registries or
  namespaces.
- Pin production runtime images by digest and update them intentionally.
- Derive the Go minor version from `go.mod`; select and persist an available
  patch version rather than silently following a moving tag.
- Cache package-manager data with `sharing=locked` when concurrent writers are
  unsafe.
- Cache both the Go module cache and Go build cache. Keep their paths aligned
  with `GOMODCACHE`, `GOPATH`, and `GOCACHE`.
- Mount the source from the build context for Go builds when the build does not
  modify it. If generators or tools write platform-specific files into the
  source tree, use `COPY` plus a deliberate `.dockerignore`.
- Keep generated outputs and the final executable outside a read-only source
  bind mount.

Read [reference/containerfile-patterns.md](reference/containerfile-patterns.md)
when creating or substantially rewriting the build.

## Handle private dependencies safely

- Install `git-lfs` in the build stage when any dependency repository uses LFS;
  otherwise fetched module content and checksums can differ by environment.
- Set `GOPRIVATE` narrowly for private module prefixes.
- Prefer an SSH agent mount for private Git access:
  - Configure Git URL rewriting only for the required hosts.
  - Supply verified host keys through `known_hosts`.
  - Forward the agent with `RUN --mount=type=ssh`; never copy private keys.
- Prefer secret mounts for `.netrc`, Go environment files, CA bundles, tokens,
  and authenticated proxy settings.
- Never bake credentials into `ARG`, `ENV`, `COPY`, a layer, or the final image.
- If a runtime cannot expose a needed proxy value as a secret, explain the
  limitation and use a credential-stripping forward proxy or another safer
  mechanism before accepting a build argument.

Treat `--mount=type=secret` as secret transport, even when it is used simply to
mount one host file. Do not let the convenient file-mount behavior weaken the
credential model.

## Design the runtime contract

- Use exec-form `ENTRYPOINT` and `CMD`.
- Put the fixed executable in `ENTRYPOINT`. Use `CMD` only for default arguments
  callers should be able to replace as a group.
- Avoid `VOLUME` in the image. Declare mounts at deployment time, especially
  when the destination already exists in the image.
- Make the application work with an arbitrary runtime UID when practical.
  Create writable paths deliberately and do not require an entrypoint to switch
  from root to another user.
- Run with a read-only root filesystem in production. Mount explicit writable
  volumes or temporary filesystems only where the application needs them.
- Prefer a rootless container runtime for local development where supported.

## Support multiple platforms deliberately

- Pass the target platform to the container build and let multi-platform base
  image indexes select the matching image.
- Use a multi-platform digest when pinning an image index. If only
  platform-specific manifests are available, maintain an explicit digest per
  target platform.
- Confirm `GOOS`, `GOARCH`, and CGO behavior for every target. Cross-compiling
  pure Go is different from executing foreign-architecture build steps.
- Use emulation only when a build step must execute target binaries; expect it
  to be slower and ensure `binfmt_misc` and the emulator are available.
- Tag or publish outputs so their platform is unambiguous, or publish a manifest
  list containing all supported platforms.

## Validate the result

- Build once with Docker or Podman as requested.
- Rebuild after a no-op source change and confirm dependency and build caches
  are reused.
- Inspect the final image to ensure build tools, source, credentials, and secret
  mounts are absent.
- Run the image with:
  - a non-root or arbitrary UID;
  - a read-only root filesystem;
  - only the declared writable mounts;
  - the intended arguments and signals.
- Test network and certificate behavior when private modules or a corporate
  proxy are involved.
- Build and smoke-test every requested platform.
- Report any runtime-specific compromise instead of presenting it as portable.

## Review checklist

- Is every image reference fully qualified?
- Is the final base reproducibly pinned without breaking multi-platform builds?
- Does the final image contain only runtime requirements?
- Are module, build, and package-manager caches mounted with safe sharing modes?
- Do multiline `RUN` instructions use heredocs?
- Can any credential enter build history, cache exports, logs, or image layers?
- Does the source-mount strategy leave the working tree unchanged?
- Does the image work under an arbitrary UID and read-only root filesystem?
- Were Docker and Podman differences verified rather than assumed?
