---
name: docker
description: Write or modify Dockerfile and docker-compose. Multi-stage, pinned base, secret-safe, cache-aware, non-root.
category: infra
version: 0.1.0
triggers: ["write Dockerfile", "edit Dockerfile", "docker-compose", "containerize", "build image"]
applies_to: [openclaw, cursor, claude-code]
---

# Docker Discipline

You write and modify Dockerfiles and docker-compose files. You match the project's existing
container conventions before introducing your own, build images that are small, cached
correctly, run as a non-root user, and never bake secrets into layers. You are
stack-agnostic — the rules below apply identically to Node, Python, Go, Java, Ruby, and
anything else that gets containerised.

See [`EXAMPLES.md`](./EXAMPLES.md) for annotated Dockerfile, `.dockerignore`, secret-mount,
and `docker-compose.yml` examples that pair with the rules in this file.

## Preflight (do this before writing or editing any container file)

The rules in this skill close concrete AI failure modes (unpinned `latest`, secrets in
`ARG`, `COPY . .` before install, missing `.dockerignore`, root in final stage). Empirical
behaviour: agents that read the existing `Dockerfile` first skip almost all of these
mistakes. Agents that start writing first hit every one.

- [ ] **Routing check.** Is this an **edit to an existing `Dockerfile` / `docker-compose.yml`**,
      or a **new image from scratch**? If the file exists, you are editing — open it first,
      do not draft a parallel one. Creating a second `Dockerfile.new` is a Preflight failure.
- [ ] **Convention discovery, before any change.** Read in this order, stop when you have
      enough to match style: existing `Dockerfile` and `Dockerfile.*` variants → `docker-compose.yml`
      / `compose.yml` → `.dockerignore` → any `Makefile` / `package.json` / `pyproject.toml`
      scripts that invoke `docker build`. Note: base image and tag, build tool (multi-stage
      pattern, `buildx`, `bake`), package manager, non-root user setup, entrypoint shape.
      **Match it.** Do not introduce a second runtime (e.g. switching `python:3.12-slim`
      to `alpine` "because it's smaller") without an explicit reason and the user's nod.
- [ ] **Out-of-scope check.** If the request is for Kubernetes manifests, Helm charts,
      ECS task definitions, Docker Swarm, or CI/CD pipeline wiring, stop. This skill
      does not cover those — say so and route the work elsewhere.
- [ ] **Secrets path.** Before writing any `ARG` or `ENV`, decide where secrets will come
      from at **build time** (BuildKit `--secret`, never `ARG`) and at **runtime**
      (orchestrator env / mounted file, never `ENV` in the image). If you cannot answer
      both, ask before writing.

## When to use

- New `Dockerfile` for a service or tool
- Editing an existing `Dockerfile` (base image bump, stage reshuffle, dep install change)
- Writing or modifying `docker-compose.yml` / `compose.yml` for local dev or single-host deploy
- Adding or fixing `.dockerignore`
- Reviewing your own diff before committing a container change

Do not invoke for Kubernetes manifests, Helm, ECS, Swarm, or CI pipeline YAML — those
are separate concerns and out of scope (see below).

## Scope

In scope:
- `Dockerfile` syntax, stage layout, layer ordering, cache behaviour
- Base image selection and pinning
- Build-time vs runtime secret handling
- `.dockerignore` contents
- Non-root user, filesystem permissions inside the image
- `HEALTHCHECK` realism
- `docker-compose.yml` / `compose.yml` services, volumes, networks for local dev
- Image size and layer hygiene where it affects pull time or attack surface

Out of scope:
- Kubernetes manifests, Helm charts, Kustomize overlays
- ECS task definitions, Fargate config
- Docker Swarm stacks and services
- CI/CD pipeline files (GitHub Actions, GitLab CI, etc.). Do not edit them unless
  explicitly requested. Existing CI build commands **may** be inspected to discover build
  args, targets, platforms, build contexts, and registry / tag conventions — those are
  inputs to the Dockerfile decision. Editing the pipeline itself stays out of scope.
- Registry mirroring, image signing infrastructure (cosign keys, Notary servers) — flag
  the gap, route to ops
- Host-level Docker daemon hardening, rootless Docker setup
- Application code changes — limit edits to container files and `.dockerignore`

## Inherits

- [`meta/engineering-principles`](../../meta/engineering-principles/SKILL.md) — DRY, file size, naming, modern standards. Non-negotiable.
- [`meta/reuse-before-create`](../../meta/reuse-before-create/SKILL.md) — before adding a new stage, base image, or compose service, check for an existing one that fits or extends. Never write a parallel `Dockerfile.<thing>` if the existing one can take an `ARG` or a build target.
- [`meta/token-discipline`](../../meta/token-discipline/SKILL.md) — read the container files and `.dockerignore`, not the entire app source.

## Token discipline (specific)

Inherit [`meta/token-discipline`](../../meta/token-discipline/SKILL.md). Additionally:

- **Dockerfile and `.dockerignore` are read together** — they are inseparable, because
  the ignore file determines what `COPY . .` actually copies. Reading one without the
  other gives an incomplete picture of the build context. Preflight reads both.
- Read **`docker-compose.yml` / `compose.yml`, dependency manifest, and CI build
  commands only when they affect the change**: build context, entrypoint, exposed ports,
  build args, build targets, multi-arch platforms, or runtime env contract. If none of
  those are in scope for the current edit, skip them.
- Read the dependency manifest (`package.json`, `pyproject.toml`, `go.mod`, `pom.xml`,
  `Gemfile`) only when you need the entrypoint command or to confirm install steps. Do
  not read application source files — the manifest is enough.
- Do not read the build cache, `node_modules/`, `.venv/`, `target/`, `build/`, or any
  output directory. They are not inputs to a Dockerfile decision.
- For base image research, do not browse Docker Hub. Use the version already in the
  project, or ask the user which tag they want.

## Rules

Each rule below closes a concrete failure mode. Apply all of them; the linter and reviewer
will look for these specifically.

### 1. Pin the base image

- ❌ `FROM node:latest` — rebuilds are non-deterministic; "latest" today is a different
  image tomorrow, and a vulnerability fix yesterday is gone today.
- ❌ `FROM node` — same problem, implicit `:latest`.
- ✅ `FROM node:20.11.1-bookworm-slim` — major, minor, patch, and distro pinned.
- ✅ `FROM node:20.11.1-bookworm-slim@sha256:<digest>` when reproducibility matters more
  than ease of upgrade (release pipelines, regulated builds).

If the project already pins a specific tag, match its precision. Do not downgrade a
digest-pinned image to a tag-only pin.

### 2. Multi-stage: build stage and runtime stage are separate

A single-stage image ships your compiler, dev dependencies, package manager caches, and
source tree to production. Use multi-stage for any compiled or built artifact (TypeScript,
Go, Java, Rust, bundled frontends, native modules).

Shape: `FROM ... AS build` installs deps and produces the artifact; `FROM ... AS runtime`
re-installs prod-only deps, copies the artifact from `build` via `COPY --from=build`,
switches to a non-root `USER`, and runs with exec-form `CMD`. See **EXAMPLES.md** for the
annotated full file.

If the project already uses multi-stage, match its stage names. Do not rename `build` to
`builder` or vice versa just because.

### 3. Order COPY for cache, not for readability

The dependency manifest changes rarely; source changes constantly. Copy the manifest and
install **before** copying source. `COPY . .` as the first COPY busts the install cache
on every code change.

- ❌ `COPY . . && RUN npm install` — every code edit reinstalls every dep.
- ✅ `COPY package.json package-lock.json ./` → `RUN npm ci` → `COPY . .` — install
  layer cached until the manifest changes.

Same pattern for `pyproject.toml` / `poetry.lock`, `requirements.txt`, `go.mod` / `go.sum`,
`Cargo.toml` / `Cargo.lock`, `pom.xml`, `Gemfile` / `Gemfile.lock`.

### 4. Secrets never enter the image

- ❌ `ARG NPM_TOKEN=...` — the value is recorded in `docker history`, even if unset at runtime.
- ❌ `ENV API_KEY=hardcoded` — visible in `docker inspect` and every layer below it.
- ❌ `COPY .env .env` — bakes the file into the image; rebases of the image carry it forward.
- ✅ Build-time secrets: BuildKit `--mount=type=secret` (see EXAMPLES.md for the full
  `RUN --mount` shape and the matching `docker build --secret` invocation).
- ✅ Runtime secrets: injected by the orchestrator (`docker run --env-file`, compose
  `secrets:`, K8s `Secret`). The image declares the *name* it expects, not the value.

If you find a secret in `ARG` or `ENV` in the existing Dockerfile, flag it as a finding
before continuing — the value is already in the registry layers.

### 5. `.dockerignore` exists and is not empty

Without `.dockerignore`, `COPY . .` ships `.git/`, `.env`, `node_modules/`, build output,
editor configs, and anything else in the working tree into the build context. Patterns
commonly excluded when not needed in the build context: `.git`, `.env` and `.env.*`,
dependency caches (`node_modules`, `.venv`, `__pycache__`), build output (`target`,
`build`, `dist`), logs, editor metadata (`.idea`, `.vscode`), `.DS_Store`, the Dockerfile
and `docker-compose*.yml` themselves, and `README.md`. **Re-include with `!path` when a
file actually belongs in the build context** — e.g. `README.md` consumed by a packaging
step, or a Dockerfile copied into the image for a metadata layer. See EXAMPLES.md for a
starter `.dockerignore`.

The build context is rebuilt every time you run `docker build`; an unfiltered context
makes builds slower and leaks history into images.

### 6. Run as non-root in the final stage

The final stage runs the application. It must not be root.

- ❌ Final stage with no `USER` directive — defaults to root.
- ❌ `USER root` left in the final stage from an earlier copy or chown step.
- ✅ Use the runtime image's built-in user where it exists (`USER node`, `USER nobody`),
  or create one explicitly with `groupadd --system` + `useradd --system` in a single
  `RUN` layer before the final `USER` switch (see EXAMPLES.md).

Any `chown`, `chmod`, or `apt-get install` belongs **before** the final `USER` switch,
not after.

### 7. `HEALTHCHECK` only if it actually checks health

A `HEALTHCHECK` is useful when the orchestrator uses it. It is harmful when it lies —
returning healthy because `curl` is missing and the shell errored out, or because the
command checks the wrong port.

- ❌ `HEALTHCHECK CMD curl -f http://localhost:8080/health` — when `curl` is not installed
  in a `-slim` or `-distroless` image.
- ❌ Healthcheck on a port the app does not listen on.
- ✅ Use a probe that exists in the image: `wget -qO- ...`, `node -e ...`, a tiny binary
  copied in for this purpose, or `HEALTHCHECK NONE` and let the orchestrator probe.
- ✅ If the orchestrator (K8s, ECS) does its own liveness/readiness probe, prefer
  `HEALTHCHECK NONE` in the Dockerfile so there's one source of truth.

### 8. One process, predictable entrypoint

- ✅ `CMD ["node", "dist/server.js"]` — exec form, signals reach the process, PID 1
  behaves correctly.
- ❌ `CMD node dist/server.js` — shell form wraps in `/bin/sh -c`, breaks `SIGTERM`
  handling, and on `-distroless` images there is no shell at all.
- For init / signal handling on multi-child workloads, use `tini` or the image's
  documented init mechanism — do not write your own bash supervisor.

### 9. `docker-compose.yml` for local dev follows the same rules

- Pin image tags in `image:` exactly like Dockerfile `FROM`.
- Do not put real secrets in `environment:` blocks committed to git. Use `env_file:`
  pointing to a gitignored `.env`, or compose `secrets:`.
- Bind-mount source for local dev (`./src:/app/src`) is fine; never bind-mount over
  `/app/node_modules` or equivalent — it shadows the installed deps with the host's.
- Name services after their role (`api`, `worker`, `db`), not after the image.

## Output format

When proposing a new or revised container file, present in this order:

```
1. Context discovered
   - Existing base: <image:tag or "none">
   - Existing stages: <names or "single-stage">
   - Existing user: <name or "root (problem)">
   - .dockerignore present: <yes/no, key entries>
2. Diff or full file — the change, or full contents for a new file.
3. Rules applied
   - Pinned base: <tag chosen, why>
   - Stages: <names and what each contains>
   - Cache order: <manifest before source>
   - Secrets: <build-time mechanism, runtime expectation>
   - User: <non-root user name>
   - Healthcheck: <command, or NONE + orchestrator probe>
4. Follow-ups (if any) — e.g. "existing image has ENV API_KEY=... in layer 3; rotate and remove."
```

For a `docker-compose.yml` change, add a `Services touched` line listing each service and
the one-line reason for each change.

## Anti-patterns

- ❌ `FROM <anything>:latest` or unpinned tag in a committed file
- ❌ `COPY . .` before the dependency install step
- ❌ `ARG` or `ENV` carrying a real secret value
- ❌ `COPY .env` (or any committed env file with real values) into the image
- ❌ Single-stage image that ships dev dependencies, source, and toolchain to production
- ❌ Missing `.dockerignore`, or one that does not exclude `.git` and `.env`
- ❌ Final stage running as root (no `USER` directive, or `USER root` left behind)
- ❌ `HEALTHCHECK` that calls a binary not present in the image
- ❌ `CMD` in shell form when exec form would work — breaks signal handling
- ❌ Creating `Dockerfile.new` / `Dockerfile.v2` instead of editing the existing one
- ❌ Switching base image family (Debian ↔ Alpine, glibc ↔ musl) without flagging the
  binary-compatibility risk for native modules
- ❌ Bind-mounting host source over an installed dependency directory in compose
- ❌ Writing K8s, Helm, ECS, or CI YAML "while we're here" — out of scope; route it

## Notes

**Base image choice.** Match what the project already uses. If there is no precedent,
prefer the official slim variant (`-bookworm-slim`, `-slim`, `-alpine` only if you've
confirmed no native module incompatibility). Distroless is excellent for production but
harder to debug — flag the trade-off if proposing it.

**BuildKit assumed.** Examples assume BuildKit (`# syntax=docker/dockerfile:1.7+`). If
the project is on a Docker version without BuildKit, the secret-mount pattern in rule 4
is not available — say so explicitly and recommend the upgrade rather than falling back
to `ARG`-based secrets.

**Multi-arch.** If the project ships both `linux/amd64` and `linux/arm64`, ensure base
tags exist for both and that any `RUN` step downloading binaries picks the right arch
(`$TARGETARCH`). Discipline rule, not an excuse to introduce multi-arch where it isn't
needed.
