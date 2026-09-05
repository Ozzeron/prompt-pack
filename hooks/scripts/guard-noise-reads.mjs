#!/usr/bin/env node
/**
 * Enforces meta/token-discipline: the agent does not spend its attention budget on
 * dependency trees, build output, or generated blobs.
 *
 * BLOCKED outright — reading these is never the shortest path to an answer, and the
 * content actively pollutes the context with patterns from code the project does not own:
 *   node_modules/, vendor/bundle/, .git/objects/, lockfiles, minified or map files
 *
 * ASK instead of block — legitimately useful when debugging a build, so the user
 * decides rather than the hook:
 *   dist/, build/, .next/, out/, .nuxt/, target/, coverage/, .turbo/, .venv/
 *
 * Anything else passes through untouched.
 */
import { guard, decide, normalize } from './lib.mjs';

const BLOCK = [
  { re: /(^|\/)node_modules\//, what: 'node_modules' },
  { re: /(^|\/)\.git\/(objects|logs|refs)\//, what: 'git internals' },
  { re: /(^|\/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|poetry\.lock|Cargo\.lock|composer\.lock|Gemfile\.lock)$/,
    what: 'a lockfile' },
  { re: /\.(min\.js|min\.css|js\.map|css\.map)$/, what: 'a minified or source-map artifact' },
  { re: /(^|\/)vendor\/bundle\//, what: 'vendored gems' },
];

const ASK = [
  /(^|\/)(dist|build|out|coverage|target)\//,
  /(^|\/)\.(next|nuxt|turbo|svelte-kit|venv|tox)\//,
  /(^|\/)__pycache__\//,
];

// Read passes file_path; Grep and Glob pass an optional path to scope the search.
function targetPath(payload) {
  const input = payload.tool_input || {};
  return normalize(input.file_path || input.path || input.notebook_path || '');
}

guard((payload) => {
  const path = targetPath(payload);
  if (!path) return;

  for (const { re, what } of BLOCK) {
    if (re.test(path)) {
      decide(
        'deny',
        `token-discipline: ${what} is off-limits (${path}). It is never the shortest path to an ` +
          'answer and it fills the context with code this project does not own. Read the ' +
          "project's own source, or the dependency's published docs, instead.",
      );
    }
  }

  for (const re of ASK) {
    if (re.test(path)) {
      decide(
        'ask',
        `token-discipline: ${path} is build output, not source. Confirm this read is about ` +
          'the build itself — otherwise read the source that produced it.',
      );
    }
  }
});
