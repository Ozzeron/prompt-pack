#!/usr/bin/env node
/**
 * Enforces the dependency bar from meta/engineering-principles: a new dependency is a
 * perpetual maintenance, security, and bundle-size cost, so it has to clear one of
 * cryptographic correctness, parsing complexity, runtime compatibility, or large surface
 * — and the justification belongs in the handoff, written before the install runs.
 *
 * Fires on an install command that names at least one package. Restore commands
 * (`npm install`, `npm ci`, `pnpm install --frozen-lockfile`, `poetry install`) name no
 * package and pass through: they add nothing that was not already committed.
 *
 * Decision is "ask" — plenty of installs are correct, the point is that the bar is
 * checked at the moment of the install rather than remembered afterwards.
 */
import { guard, decide } from './lib.mjs';

// [pattern, manifest the package would land in]. The trailing group must capture at least
// one non-flag token for the rule to fire.
const INSTALLERS = [
  { re: /\b(?:npm|pnpm|yarn|bun)\s+(?:install|i|add)\b([^&|;]*)/, manifest: 'package.json' },
  { re: /\b(?:pip|pip3)\s+install\b([^&|;]*)/, manifest: 'requirements.txt / pyproject.toml' },
  { re: /\b(?:poetry|uv|pdm)\s+add\b([^&|;]*)/, manifest: 'pyproject.toml' },
  { re: /\bcargo\s+add\b([^&|;]*)/, manifest: 'Cargo.toml' },
  { re: /\bgo\s+get\b([^&|;]*)/, manifest: 'go.mod' },
  { re: /\bcomposer\s+require\b([^&|;]*)/, manifest: 'composer.json' },
  { re: /\bgem\s+install\b([^&|;]*)/, manifest: 'Gemfile' },
  { re: /\bdotnet\s+add\s+package\b([^&|;]*)/, manifest: 'the .csproj' },
];

// Flags and lockfile-only switches are not package names.
function packagesIn(tail) {
  return tail
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(Boolean)
    .filter((t) => !t.startsWith('-'))
    .filter((t) => !/^(?:-r|requirements\.txt)$/.test(t));
}

guard((payload) => {
  const command = (payload.tool_input || {}).command;
  if (!command || typeof command !== 'string') return;

  for (const { re, manifest } of INSTALLERS) {
    const m = command.match(re);
    if (!m) continue;
    const packages = packagesIn(m[1] || '');
    if (packages.length === 0) return; // restore, not an addition

    decide(
      'ask',
      `engineering-principles: this adds ${packages.slice(0, 4).join(', ')} to ${manifest}. ` +
        'Confirm first that no current dependency already covers it, that it is not a 5-line ' +
        'helper (debounce, groupBy, slugify, clamp, sleep), and that it clears one of the bars: ' +
        'cryptographic correctness, parsing complexity, runtime compatibility, large surface. ' +
        'The one-line justification goes in the handoff.',
    );
  }
});
