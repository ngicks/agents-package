# Go

Go-specific Containerfile guidance.
Source: https://zenn.dev/ngicks/articles/go-basics-revisited-bulding-with-docker plus widely known practices.
Apply on top of the general practices in [../SKILL.md](../SKILL.md);
everything generic (base pinning, credentials, SSH/secret mounts, proxy and CA handling,
multi-platform builds, runtime contract) lives there and is not repeated here.

## Worked example with decision points

```dockerfile
# syntax=docker/dockerfile:1

# Decision: Go version — derive the minor from go.mod (`go`/`toolchain` directives),
# select the latest available patch deliberately; never a bare moving tag.
FROM docker.io/library/golang:<major.minor.patch>-<distro> AS build

# Decision: CGO — 0 only when no dependency needs cgo; confirm with a real build.
# When cgo is required, keep the matching libc in the runtime image instead.
ENV CGO_ENABLED=0

WORKDIR /app/src

# Decision: bind-mount the source (go build does not write into the tree);
# fall back to whole-context `COPY . .` + .dockerignore (never per-file COPY)
# if generators write into the source.
# Decision: Go caches are concurrency-safe — no sharing=locked.
# /go covers GOPATH (GOMODCACHE=/go/pkg/mod); /root/.cache/go-build is GOCACHE.
# Keep -o output outside the read-only source mount.
RUN --mount=type=bind,target=/app/src \
    --mount=type=cache,target=/go \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/bin/app ./cmd/app

# Decision: runtime base, digest-pinned:
#   scratch                              -> no CA certs, tzdata, shell needed
#   gcr.io/distroless/static-debian12    -> needs CA certs and/or tzdata
#   small distro image                   -> operators need a shell
FROM gcr.io/distroless/static-debian12@sha256:<digest>

COPY --from=build /app/bin/app /app

# Decision: fixed binary in ENTRYPOINT, replaceable defaults in CMD, exec form.
ENTRYPOINT ["/app"]
CMD ["--listen=:8080"]
```

## Toolchain version

- Build in `docker.io/library/golang:<version>-<distro>` (fully qualified).
- Derive the Go version from `go.mod` (`go` and `toolchain` directives).
  - Prefer the latest patch of the declared minor over a hard-coded stale patch;
    resolve it deliberately (e.g. a helper that lists upstream versions) rather than following a moving tag silently.

## Go-specific environment variables

- `CGO_ENABLED=0` when no dependency needs cgo; the static binary then runs on `scratch` or `distroless/static`.
  - Do not assume pure Go: confirm from dependencies and a real build.
  - When cgo is required, keep the matching libc and shared libraries in the runtime image.
  - Runtime files a static binary may still need: a CA bundle for `crypto/x509`
    (carried by distroless, or supplied deliberately), and timezone data —
    embeddable in the binary with `time/tzdata` instead.
- `GOOS`/`GOARCH`: pure Go cross-compiles; set them from the `TARGETOS`/`TARGETARCH`
  build args and keep the build stage on `--platform=$BUILDPLATFORM`.
  No QEMU emulation is needed for pure-Go builds.
- `GOPRIVATE`: set narrowly to the private module prefixes so the public proxy
  and sumdb are not consulted for internal modules.
- `GOPROXY`: point at an internal module proxy (Artifactory, Athens, Nexus, GitLab)
  to sidestep build-time git entirely; auth per the credential rules in `../SKILL.md`.
- `GOFLAGS=-mod=vendor` with a committed `vendor/` tree (`go mod vendor` before
  the image build) removes build-time credentials and dependency network access altogether.
- `GOPATH`/`GOMODCACHE`/`GOCACHE`: see Caching below; keep cache mount targets aligned with them.

## Caching

- Go's module and build caches are safe for concurrent access;
  mount them without `sharing=locked`.
- `/go` covers `GOPATH` (hence `GOMODCACHE=/go/pkg/mod`);
  `/root/.cache/go-build` is `GOCACHE`.
  Keep mount targets aligned with those env vars if the image changes them.

## Source mounting

Go builds do not write into the source tree, so bind-mount it instead of `COPY`
(shown in the worked example above).

- Keep outputs (`-o`) outside the read-only mount.
- This is Go-specific; languages whose builds write into the tree must use `COPY`.
- If generators write into the source tree, fall back to a whole-context `COPY . .`
  with a maintained `.dockerignore`; never a per-file `COPY` list, which breaks
  silently when files are added.

## go mod download and credentials

- Install `git-lfs` in the build stage when any dependency repo uses LFS;
  otherwise fetched module content and checksums can differ by environment.
- SSH access mechanics (agent forwarding, `known_hosts`, git `insteadOf` rewriting
  scoped to the required hosts, Buildah's SSH-agent caveats) follow the generic
  rules in `../SKILL.md`.
- Mount the Go env file or `.netrc` as secrets, not files or args.

```dockerfile
# Decision: SSH agent forwarding for private Git; never copy keys.
# Podman/Buildah: unlock keys first (2s connection close; see ../SKILL.md).
RUN --mount=type=ssh \
    --mount=type=cache,target=/go \
    go mod download

# Decision: Go env file as a secret mount, never ARG/ENV/COPY.
RUN --mount=type=secret,id=goenv,target=/root/.config/go/env \
    --mount=type=cache,target=/go \
    go mod download

# Decision: HTTPS-only host — token via .netrc secret mount, never in layers.
RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    --mount=type=cache,target=/go \
    go mod download
```
