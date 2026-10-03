// AD-49 retired Firestore keys, read from the inventory in
// `tool/retired_symbols/` (DNI-489, Story 1.27).
//
// A rules or Cloud Functions test that proves a retirement holds (a write
// adding a retired key is refused) takes the keys from here instead of
// spelling them. The retired-test-reference gate
// (`tool/check_retired_test_references.dart`) then stays empty, and a key
// retired later is covered with no test change.

import { readFileSync } from 'node:fs';

const INVENTORY = new URL('../../tool/retired_symbols/', import.meta.url);
const SNAKE = /^[a-z][a-z0-9]*(_[a-z0-9]+)*$/;
const CAMEL = /^[a-z][a-z0-9]*([A-Z][a-z0-9]*)+$/;

function expandBraces(pattern) {
  const match = /\{([^{}]*)\}/.exec(pattern);
  if (!match) return [pattern];
  return match[1].split(',').flatMap((alternative) => expandBraces(
    pattern.slice(0, match.index) + alternative + pattern.slice(match.index + match[0].length),
  ));
}

function matches(glob, path) {
  const escaped = glob.replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*\*/g, '\u0000').replace(/\*/g, '[^/]*').replace(/\u0000/g, '.*');
  return new RegExp(`^${escaped}$`).test(path);
}

/**
 * The retired Firestore keys of the code at `libPath` in inventory `group`:
 * every retired snake_case `field` entry whose `paths` scope covers
 * `libPath`, plus the group's unscoped ones, in inventory order. `aliases`
 * adds the retired camelCase spelling of each of those keys.
 */
export function retiredKeysOf(libPath, { group = 'R16', aliases = false } = {}) {
  const { entries } = JSON.parse(readFileSync(new URL(`${group}.json`, INVENTORY), 'utf8'));
  const keys = new Set();
  const camelSpellings = new Set();
  for (const entry of entries) {
    if (entry.kind !== 'field' || entry.state !== 'retired') continue;
    if (CAMEL.test(entry.symbol)) {
      camelSpellings.add(entry.symbol);
      continue;
    }
    if (!SNAKE.test(entry.symbol)) continue;
    const include = entry.paths?.include;
    if (include && !include.some((p) => expandBraces(p).some((g) => matches(g, libPath)))) {
      continue;
    }
    keys.add(entry.symbol);
  }
  if (aliases) {
    for (const key of [...keys]) {
      const camel = key.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
      if (camel !== key && camelSpellings.has(camel)) keys.add(camel);
    }
  }
  if (keys.size === 0) throw new Error(`No retired ${group} keys cover ${libPath}`);
  return [...keys];
}
