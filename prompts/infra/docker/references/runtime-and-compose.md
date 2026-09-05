# Runtime, ignore-file, and compose rules

> Reference for [docker](../SKILL.md). Load it when the change touches .dockerignore, the final-stage user, HEALTHCHECK, the entrypoint, or docker-compose.

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
