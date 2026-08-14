/**
 * Shared plumbing for the PreToolUse guards.
 *
 * Contract with the harness (see code.claude.com/docs/en/hooks):
 *   - stdin  : one JSON object with tool_name, tool_input, cwd, permission_mode, ...
 *   - stdout : {"hookSpecificOutput": {"hookEventName": "PreToolUse",
 *                "permissionDecision": "allow"|"deny"|"ask",
 *                "permissionDecisionReason": "..."}}
 *   - exit 0 with no stdout means "no decision" and the normal permission flow runs.
 *
 * Everything here fails open on purpose: a guard that throws would otherwise turn
 * into an outage for whoever installed the pack.
 */
import { readFileSync } from 'node:fs';

export function readPayload() {
  try {
    const raw = readFileSync(0, 'utf8');
    if (!raw.trim()) return null;
    const payload = JSON.parse(raw);
    return payload && typeof payload === 'object' ? payload : null;
  } catch {
    return null;
  }
}

export function decide(decision, reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: decision,
        permissionDecisionReason: reason,
      },
    }),
  );
  process.exit(0);
}

/** No decision: let the normal permission flow handle it. */
export function passThrough() {
  process.exit(0);
}

/**
 * Run a guard with fail-open semantics. `fn` receives the parsed payload and either
 * calls decide() or returns.
 */
export function guard(fn) {
  try {
    const payload = readPayload();
    if (!payload) passThrough();
    fn(payload);
  } catch {
    // Never let an internal error block a tool call.
  }
  passThrough();
}

/** Forward slashes, no drive-letter case surprises — these paths are only ever matched. */
export function normalize(p) {
  return String(p || '').replace(/\\/g, '/');
}
