# Containerfile Patterns

Use these as adaptable starting points. Resolve current image versions and
digests for the repository instead of copying placeholders literally.

The examples intentionally use heredocs for `RUN` bodies. Preserve that style
when adapting them.

## Contents

- Pure-Go image
- Build with private modules over SSH
- Build behind a corporate proxy
- Cache and source-mount decisions
- Build invocation

## Pure-Go image

```dockerfile
# syntax=docker/dockerfile:1

ARG GO_VERSION
ARG GO_DISTRO=bookworm

FROM docker.io/library/golang:${GO_VERSION}-${GO_DISTRO} AS builder

ARG MAIN_PACKAGE=.

ENV CGO_ENABLED=0 \
    GOCACHE=/root/.cache/go-build \
    GOMODCACHE=/go/pkg/mod

WORKDIR /src

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,target=/src \
<<EOF
    set -eu
    mkdir -p /out
    go build -trimpath -o /out/app "${MAIN_PACKAGE}"
EOF

FROM gcr.io/distroless/static-debian12@sha256:<resolved-multi-platform-digest>

COPY --from=builder /out/app /app

ENTRYPOINT ["/app"]
```

Adapt the final stage when the binary needs CGO, CA certificates, timezone
data, user records, or other runtime files. Do not force `scratch` or
distroless when the executable contract requires more.

The final stage intentionally declares no `USER`. Keep it that way: supply the
runtime UID and read-only root filesystem at deployment, as described in the
runtime contract section of SKILL.md.

## Build with private modules over SSH

Install only the clients required to fetch dependencies. Keep package-manager
caches out of image layers and lock caches that do not support concurrent
writes.

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
    set -eu
    rm -f /etc/apt/apt.conf.d/docker-clean
    printf '%s\n' 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
    apt-get update
    apt-get install -y --no-install-recommends git-lfs openssh-client
    git lfs install
EOF

ARG SSH_HOSTS=github.com

RUN <<EOF
    set -eu
    mkdir -p -m 0700 /root/.ssh
    for host in $(printf '%s' "${SSH_HOSTS}" | tr ',' ' '); do
      git config --global "url.ssh://git@${host}/.insteadOf" "https://${host}/"
    done
EOF
```

Mount a reviewed `known_hosts` file rather than trusting unverified
`ssh-keyscan` output produced inside the build:

```dockerfile
RUN --mount=type=ssh \
    --mount=type=secret,id=known_hosts,target=/root/.ssh/known_hosts,required=true \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,target=/src \
<<EOF
    set -eu
    go mod download
    mkdir -p /out
    go build -trimpath -o /out/app "${MAIN_PACKAGE}"
EOF
```

Invoke with the agent socket and reviewed host keys:

```sh
docker buildx build \
  --ssh default \
  --secret id=known_hosts,src="$HOME/.ssh/known_hosts" \
  --build-arg GOPRIVATE=github.com/example \
  --build-arg GO_VERSION=1.xx.y \
  --tag example/app:dev \
  .
```

For Podman or Buildah backed by a passphrase-protected agent, unlock the key
before starting the build if interactive agent confirmation cannot complete
within the backend timeout.

## Build behind a corporate proxy

Assume proxy URLs may contain credentials. Prefer secret-backed environment
mounts where the selected builder supports them:

```dockerfile
ARG SSL_CERT_FILE=/run/secrets/corporate-ca

RUN --mount=type=secret,id=corporate-ca,target=/run/secrets/corporate-ca,required=true \
    --mount=type=secret,id=netrc,target=/root/.netrc \
    --mount=type=secret,id=HTTP_PROXY,env=HTTP_PROXY \
    --mount=type=secret,id=HTTPS_PROXY,env=HTTPS_PROXY \
    --mount=type=secret,id=NO_PROXY,env=NO_PROXY \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,target=/src \
<<EOF
    set -eu
    go mod download
    mkdir -p /out
    go build -trimpath -o /out/app "${MAIN_PACKAGE}"
EOF
```

- Mount the corporate CA bundle without replacing a package-managed CA path
  when avoidable.
- Set tool-specific CA variables only for tools actually used. Go and many
  command-line clients honor `SSL_CERT_FILE`; Node.js and Deno have their own
  variables.
- Use short-lived credentials in `.netrc`.
- Do not forward SSH if the corporate network blocks it; use authenticated
  HTTPS with secret-mounted credentials.
- Do not fall back to credential-bearing build arguments silently. Containerfile
  arguments and build logs are not a safe secret channel.

Builder implementations differ. Verify secret-to-environment support on the
actual Docker, Podman, or Buildah version before depending on it.

## Cache and source-mount decisions

Prefer a source bind mount when all of these are true:

- The entire build context is available to the builder.
- The Go build and generators do not modify source paths.
- Outputs can be directed outside the mounted tree.

Prefer `COPY` and a deliberate `.dockerignore` when:

- CI sends an assembled context that cannot be mounted as expected.
- Code generation writes into the repository.
- Native tools may produce host- or target-specific files beside sources.
- Later stages need copied source artifacts.

For a `COPY` workflow, split dependency metadata from source when it produces a
measurable cache benefit:

```dockerfile
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod <<EOF
    set -eu
    go mod download
EOF

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
<<EOF
    set -eu
    mkdir -p /out
    go build -trimpath -o /out/app "${MAIN_PACKAGE}"
EOF
```

Do not add this split mechanically. A bind-mounted source plus persistent Go
caches often makes the extra layer choreography unnecessary.

## Build invocation

Keep the selected Go patch version in a reviewed file or CI input. Verify that
the matching builder image exists before updating it.

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg GO_VERSION="$(cat ver)" \
  --build-arg MAIN_PACKAGE=./cmd/example \
  --tag registry.example.com/team/example:VERSION \
  --push \
  .
```

For local Podman builds, substitute the compatible Podman command and verify
each requested mount feature. Do not assume every BuildKit extension has
identical Buildah behavior.
