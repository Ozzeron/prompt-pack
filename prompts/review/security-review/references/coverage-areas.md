# Coverage areas

> Reference for [security-review](../SKILL.md). Load it when you work a coverage pass: injection, authz, secrets, transport, CSRF, dependencies, rate limiting, uploads, frontend, or config.

## Coverage areas

Use these as checklists. Apply what is relevant to the code under review.

### 1. Input validation and injection

- [ ] SQL queries use parameterized statements or a safe ORM (no string concatenation with user input)
  ```js
  // ❌ db.query(`SELECT * FROM users WHERE id = ${req.params.id}`)
  // ✅ db.query('SELECT * FROM users WHERE id = $1', [req.params.id])
  ```
- [ ] NoSQL queries don't expose `$where` or operator injection via unsanitized objects
  ```js
  // ❌ User.find({ email: req.body.email })  // if body is { email: { $gt: '' } }
  // ✅ User.find({ email: String(req.body.email) })
  ```
- [ ] No `eval()`, `new Function()`, or `child_process.exec()` with user-supplied data
- [ ] Output to HTML is encoded; `dangerouslySetInnerHTML` / `innerHTML` usage is justified and sanitized (DOMPurify or equivalent)
- [ ] File path inputs don't allow `../` traversal; paths are resolved and checked against an allowed base
  ```js
  // ✅ const safe = path.resolve('/uploads', filename); if (!safe.startsWith('/uploads')) throw ...
  ```
- [ ] Server-side fetches of user-supplied URLs are blocked for private/internal IP ranges (SSRF — CWE-918)
- [ ] XML parsing disables external entity resolution (XXE — CWE-611)
- [ ] Deep-merge operations (lodash merge, Object.assign on user input) are not reachable with prototype keys (`__proto__`, `constructor`)

### 2. Authentication and authorization

- [ ] Every sensitive endpoint has an explicit auth check — not just middleware presence. Verify the middleware actually runs on these routes.
  ```js
  // ❌ router.post('/admin/delete', deleteUser)  // auth middleware only on /admin GET routes
  // ✅ router.post('/admin/delete', requireAuth, requireRole('admin'), deleteUser)
  ```
- [ ] Object-level authorization: does the code verify the current user owns the resource being accessed? (OWASP A01:2021 Broken Access Control)
  ```js
  // ❌ const doc = await Doc.findById(req.params.id)
  // ✅ const doc = await Doc.findOne({ _id: req.params.id, owner: req.user.id })
  ```
- [ ] Role/permission checks are server-side; client-supplied role claims are not trusted
- [ ] JWTs are signature-verified; `alg: none` is rejected; RS256 secrets are not confused with HS256
- [ ] Session tokens are in HttpOnly cookies, not localStorage (protects against XSS token theft)
- [ ] Logout actually invalidates the session server-side (or the token is short-lived + refresh token is revoked)
- [ ] Login error messages don't reveal whether the email exists (account enumeration — CWE-204)
  ```js
  // ❌ "No account found for that email"
  // ✅ "Invalid email or password"
  ```
- [ ] Passwords hashed with bcrypt or argon2; never MD5, SHA1, SHA256 without salt, or plaintext
- [ ] Password reset tokens are single-use, short-lived, and not predictable

### 3. Secrets and sensitive data

- [ ] No hardcoded API keys, passwords, tokens, or private keys in source code
- [ ] No secrets in environment variable names prefixed `NEXT_PUBLIC_`, `VITE_`, or `REACT_APP_` — those become client-side bundle artifacts
- [ ] Log statements don't include `password`, `token`, `secret`, `authorization`, or PII fields
- [ ] Error responses return generic messages in production; stack traces and SQL errors are not serialized into API responses (CWE-209)
- [ ] No secrets committed to git history — mention `git-secrets` or `trufflehog` as detection tools for the repo owner to run

### 4. Transport and storage

- [ ] HTTPS is enforced at the application or infrastructure level (not just "assumed" — check config files, middleware, redirects)
- [ ] Security headers are set: `Content-Security-Policy`, `Strict-Transport-Security`, `X-Frame-Options` (or `frame-ancestors` in CSP), `X-Content-Type-Options: nosniff`
- [ ] Cookies carrying session or auth data have `Secure`, `HttpOnly`, and a `SameSite` value set
- [ ] Sensitive data at rest is encrypted where regulations or risk require it; connection strings are not in plaintext config files
- [ ] Database credentials are not visible in logs, error messages, or client-accessible config

### 5. Cross-origin and CSRF

- [ ] CORS `Access-Control-Allow-Origin: *` is not combined with `Access-Control-Allow-Credentials: true` (CWE-942)
  ```js
  // ❌ cors({ origin: '*', credentials: true })
  // ✅ cors({ origin: 'https://app.example.com', credentials: true })
  ```
- [ ] State-changing endpoints (POST, PUT, PATCH, DELETE) have CSRF protection — either CSRF token, `SameSite=Strict/Lax` cookie, or custom header check
- [ ] Custom request headers used as CSRF protection (e.g. `X-Requested-With`) are actually verified server-side

### 6. Dependencies and supply chain

- [ ] No dependencies with known critical/high CVEs in `npm audit` / `pip audit` output (if provided)
- [ ] Lock files (`package-lock.json`, `yarn.lock`, `poetry.lock`) are committed and up to date
- [ ] No suspicious post-install scripts (`postinstall` in package.json running curl/bash/eval)
- [ ] Floating version ranges (`^`, `~`, `*`) on security-critical packages reviewed; pinning considered for high-risk deps

### 7. Rate limiting and abuse prevention

- [ ] Login endpoint is rate-limited (or behind a rate-limiting proxy)
- [ ] Password reset, email verification, and account recovery flows are rate-limited
- [ ] Expensive or sensitive operations (bulk export, search with heavy DB load, password change) have rate limits
- [ ] N failed login attempts → account lockout or progressive delay
- [ ] High-risk flows (account creation, payment initiation) have CAPTCHA or equivalent challenge where appropriate

### 8. File uploads

- [ ] File type validation is content-based (magic bytes / MIME sniffing), not just file extension check
- [ ] File size limits enforced server-side (not just client-side)
- [ ] Uploaded files stored outside the web root, or in a separate domain/bucket not serving executable content
- [ ] Filenames sanitized — `path.basename()`, strip `../`, strip shell metacharacters before storing or referencing
- [ ] Archives (zip, tar) validated for zip-slip before extraction

### 9. Frontend-specific

- [ ] `dangerouslySetInnerHTML` usage is audited; user-supplied strings are sanitized before being passed in
- [ ] Third-party scripts have `integrity` (SRI hash) attributes and a CSP that restricts script sources
- [ ] Sensitive data (auth tokens, PII) is not stored in `localStorage` or `sessionStorage` when HttpOnly cookies are feasible
- [ ] Hidden UI is not the only access control — server enforces the same restrictions the UI hides (CWE-602)
- [ ] Source maps are not shipped to production (exposes full original source to anyone with devtools)

### 10. Infrastructure and config

- [ ] Default admin credentials are changed; no `admin/admin`, `root/root`, etc. in config or fixtures
- [ ] S3 buckets, blob containers, and storage buckets are private unless explicitly intended to be public
- [ ] Database is not accessible from the public internet without a firewall/VPC rule
- [ ] Debug mode is disabled in production (`DEBUG=false`, `NODE_ENV=production`, Flask `debug=False`)
- [ ] Verbose error pages are disabled in production (stack traces not returned to clients)
