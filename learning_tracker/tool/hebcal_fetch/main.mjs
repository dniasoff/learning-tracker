// Hebcal calendar fetcher.
//
// Iterates every day in [START, END] (default 2024-01-01 → 2032-12-31) and
// asks @hebcal/learning for every supported track, then renders both English
// and Hebrew refs (no nikud) plus the click-through URL hebcal provides.
//
// Output: tool/data/hebcal_calendar_cache.json, shape:
//   { "YYYY-MM-DD": {
//       "<programKey>": { "en": "...", "he": "...", "url": "..." }
//     }
//   }
//
// programKey is OUR app's key (daf_yomi, perek_yomi, ...), mapped from
// hebcal's category[0] tag so the seeder doesn't need to remap.
//
// Yerushalmi: only 'yerushalmi-vilna' is enabled and is keyed as
// 'yerushalmi_yomi'. Schottenstein is intentionally skipped.
//
// Usage (from learning_tracker/):
//   cd tool/hebcal_fetch && npm install && node main.mjs
//   START=2030-01-01 END=2030-12-31 node main.mjs

import { HebrewCalendar } from '@hebcal/core';
import '@hebcal/learning';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const START = process.env.START || '2024-01-01';
const END = process.env.END || '2032-12-31';
// Resolve relative to the repo's learning_tracker/ root so callers can run
// the script from anywhere inside the tree.
const OUT = resolve(process.env.OUT || '../data/hebcal_calendar_cache.json');

// Hebcal "dailyLearning" option keys we want enabled. Schottenstein
// Yerushalmi intentionally excluded — Vilna is canonical for our app.
const ENABLED = [
  'dafYomi',
  'dafWeekly',
  'mishnaYomi',
  'nachYomi',
  'perekYomi',
  'rambam1',
  'rambam3',
  'arukhHaShulchanYomi',
  'kitzurShulchanAruch',
  'chofetzChaim',
  'shemiratHaLashon',
  'tanakhYomi',
  'psalms',
  'seferHaMitzvot',
  'yerushalmi-vilna',
  'pirkeiAvotSummer',
  'dirshuAmudYomi',
];

// Hebcal `getCategories()[0]` → our program key. Hebcal's category tags don't
// always match the option keys (e.g. 'dailyPsalms' vs 'psalms'), so this
// mapping is the canonical place to translate.
const CATEGORY_TO_KEY = {
  dafyomi: 'daf_yomi',
  dafWeekly: 'daf_a_week',
  mishnayomi: 'mishna_yomit',
  nachyomi: 'nach_yomi',
  perekYomi: 'perek_yomi',
  dailyRambam1: 'rambam_1_chapter',
  dailyRambam3: 'rambam_3_chapters',
  arukhHaShulchanYomi: 'arukh_hashulchan_yomi',
  kitzurShulchanAruch: 'kitzur_shulchan_aruch_yomi',
  chofetzChaim: 'chofetz_chaim_daily',
  shemiratHaLashon: 'shemirat_halashon',
  tanakhYomi: 'tanakh_yomi',
  dailyPsalms: 'tehillim_yomi',
  seferHaMitzvot: 'sefer_hamitzvot',
  yerushalmi: 'yerushalmi_yomi',
  pirkeiAvotSummer: 'pirkei_avot_summer',
  dirshuAmudYomi: 'dirshu_amud_hayomi',
};

const dailyLearning = Object.fromEntries(ENABLED.map((k) => [k, true]));

const startDate = new Date(`${START}T12:00:00`);
const endDate = new Date(`${END}T12:00:00`);
if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
  throw new Error(`bad date: START=${START} END=${END}`);
}

mkdirSync(dirname(OUT), { recursive: true });

const cache = {};
const unmappedCategories = new Set();
let dayCount = 0;
const began = Date.now();

for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
  const events = HebrewCalendar.calendar({
    start: new Date(d),
    end: new Date(d),
    dailyLearning,
  });
  const dateKey = d.toISOString().slice(0, 10);
  const entry = {};
  for (const ev of events) {
    const cats = ev.getCategories?.() ?? [];
    if (cats.length === 0) continue;
    const programKey = CATEGORY_TO_KEY[cats[0]];
    if (!programKey) {
      unmappedCategories.add(cats[0]);
      continue;
    }
    // renderBrief strips the program-name prefix that render() adds (e.g.
    // "Daf Yomi: Chullin 7" → "Chullin 7"). Fall back to render() for
    // events without renderBrief.
    const en = ev.renderBrief?.('en') ?? ev.render?.('en') ?? '';
    const he = ev.renderBrief?.('he-x-NoNikud') ?? ev.render?.('he-x-NoNikud') ?? '';
    if (!en) continue;
    const url = ev.url?.() ?? '';
    entry[programKey] = url ? { en, he, url } : { en, he };
  }
  cache[dateKey] = entry;
  dayCount++;
  if (dayCount % 500 === 0) {
    const elapsed = ((Date.now() - began) / 1000).toFixed(1);
    process.stderr.write(`  ${dayCount} days (${dateKey}) — ${elapsed}s\n`);
  }
}

if (unmappedCategories.size > 0) {
  process.stderr.write(
    `WARN: unmapped categories (silently skipped): ${[...unmappedCategories].join(', ')}\n`
  );
}

// Write the JSON cache. Sort top-level (date) and inner (program-key) keys
// so diffs stay clean; JSON.stringify with a replacer reorders object keys.
const sortedDates = Object.keys(cache).sort();
const ordered = {};
for (const date of sortedDates) {
  const day = cache[date];
  const sortedKeys = Object.keys(day).sort();
  ordered[date] = {};
  for (const k of sortedKeys) {
    const r = day[k];
    // Force {en, he, url} field order for stable output.
    const out = { en: r.en, he: r.he };
    if (r.url) out.url = r.url;
    ordered[date][k] = out;
  }
}

writeFileSync(OUT, JSON.stringify(ordered, null, 2) + '\n');

const elapsed = ((Date.now() - began) / 1000).toFixed(1);
process.stderr.write(
  `DONE — ${dayCount} days written to ${OUT} (${elapsed}s)\n`
);
