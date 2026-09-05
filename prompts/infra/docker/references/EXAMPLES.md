# Docker — annotated examples

Companion file to `SKILL.md`. The skill states the rules; this file shows them
applied. Examples use Node as the host stack because the patterns translate
directly to Python (`pyproject.toml` / `poetry.lock`), Go (`go.mod` / `go.sum`),
Java (`pom.xml`), Ruby (`Gemfile.lock`), and Rust (`Cargo.lock`).

## Multi-stage Dockerfile (rule 2 + rule 3 + rule 6 + rule 8)

A single-stage image ships your compiler, dev dependencies, package manager
caches, and source tree to production. Use multi-stage for any compiled or
built artifact (TypeScript, Go, Java, Rust, bundled frontends, native modules).

```dockerfile
# syntax=docker/dockerfile:1.7

# --- Build stage: has toolchain, dev deps, source ----------------------------
FROM node:20.11.1-bookworm-slim AS build
WORKDIR /app

# Manifest first → install layer is cached until deps actually change.
COPY package.json package-lock.json ./
RUN npm ci

# Source comes after install; edits here do not bust the install layer.
COPY . .
RUN npm run build

# --- Runtime stage: only what's needed to run --------------------------------
FROM node:20.11.1-bookworm-slim AS runtime
WORKDIR /app

# Re-install with prod-only deps in the runtime stage; do not COPY node_modules
# from build (mixes dev deps + native modules built for the build stage).
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Built artifact only.
COPY --from=build /app/dist ./dist

# Built-in non-root user shipped by the node image.
USER node

# Exec form: signals reach the node process, PID 1 behaves correctly.
CMD ["node", "dist/server.js"]
```

What this image does **not** do:

- It does not COPY `.git`, `.env`, or `node_modules` — those are excluded by
  `.dockerignore` (see below).
- It does not run as root in the final stage.
- It does not invalidate the install layer on every source edit.

If the project already uses multi-stage, match its stage names. Do not rename
`build` to `builder` or vice versa just because.

## BuildKit secret mount (rule 4)

Build-time secrets must never enter image layers or `docker history`. BuildKit's
`--mount=type=secret` exposes the value to one `RUN` step only; it is not
captured in any layer.

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

Invocation from the host:

```bash
docker build --secret id=npm_token,src=$HOME/.npmrc-token .
```

Runtime secrets are a different problem: inject via the orchestrator
(`docker run --env-file`, compose `secrets:`, Kubernetes `Secret`). The image
declares the *name* it expects (`ENV PORT=8080`-style placeholders are fine;
real values come from outside).

## `.dockerignore` starter (rule 5)

Commonly excluded when not needed in the build context. Extend (do not shrink)
for the project's stack. Re-include with `!path` if a specific file actually
belongs in the context (e.g. a `README.md` consumed by a packaging step).

```
.git
.gitignore
.env
.env.*
node_modules
.venv
__pycache__
target
build
dist
*.log
.DS_Store
.idea
.vscode
Dockerfile
docker-compose*.yml
README.md
```

## Explicit non-root user (rule 6)

When the base image does not ship a usable non-root user, create one in a
single layer **before** the final `USER` switch. Any `chown`, `chmod`, or
package install must happen before the switch, not after.

```dockerfile
RUN groupadd --system app \
 && useradd --system --gid app --home /app app \
 && chown -R app:app /app
USER app
```

## Healthcheck that actually checks (rule 7)

Pick a probe that exists in the image. `curl` is not present in `-slim` or
distroless images.

```dockerfile
# Good: wget exists in bookworm-slim
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8080/health || exit 1

# Better when the orchestrator probes anyway:
HEALTHCHECK NONE
```

If Kubernetes / ECS already runs liveness and readiness probes, prefer
`HEALTHCHECK NONE` in the Dockerfile so there is one source of truth.

## `docker-compose.yml` for local dev (rule 9)

```yaml
services:
  api:
    build:
      context: .
      target: runtime
    image: myorg/api:dev
    env_file: .env            # gitignored; never commit real values
    ports:
      - "8080:8080"
    volumes:
      - ./src:/app/src        # bind-mount source for hot reload
      # Do NOT add ./:/app — that shadows /app/node_modules from the image.
    depends_on:
      - db
  db:
    image: postgres:16.4-bookworm
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:

secrets:
  db_password:
    file: ./.secrets/db_password
```

Pin `image:` tags exactly like Dockerfile `FROM`. Name services after their
role (`api`, `worker`, `db`), not after the image.
