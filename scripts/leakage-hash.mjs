#!/usr/bin/env node
/**
 * Generate a private-term hash for scripts/leakage-hashes.json.
 *
 * Usage:
 *   node scripts/leakage-hash.mjs "<term>" ["<term2>" ...]
 *
 * Prints the normalized form and the sha256 hash for each term. Copy the hash
 * into the "hashes" array in scripts/leakage-hashes.json — never commit the
 * term itself. Normalization matches lint-skills.mjs: lowercase, strip every
 * character outside [a-z0-9@]. Multi-word or hyphenated terms are matched in
 * skill content as adjacent token pairs, so "some-name" and "some name" both
 * resolve to the same hash.
 */

import { createHash } from 'node:crypto';

const terms = process.argv.slice(2);
if (terms.length === 0) {
  console.error('Usage: node scripts/leakage-hash.mjs "<term>" ["<term2>" ...]');
  process.exit(1);
}

for (const term of terms) {
  const normalized = term.toLowerCase().replace(/[^a-z0-9@]/g, '');
  if (!normalized) {
    console.error(`Skipping "${term}": nothing left after normalization.`);
    continue;
  }
  const hash = createHash('sha256').update(normalized).digest('hex');
  console.log(`${term}  ->  normalized: "${normalized}"  sha256: ${hash}`);
}
