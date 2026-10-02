// Story 2.1 / DNI-492 AC-3 / AC-4 / AC-5 — the shared AD-45 fixture suite
// (test/fixtures/sub_track_limits/*.json) through the TypeScript validator
// that writeWithChangeLog runs. test/domain/learner_state/
// sub_track_limits_test.dart runs the same files through the Dart
// validator; both must agree on every case. Pure: no emulator needed.
//
// Fixture rules (identical in test/helpers/sub_track_limit_fixtures.dart):
// stored row = {...base, ...doc}; create row = {...base, ...fields}; edit
// row = {...stored, ...fields} with null clearing a field; `program_id` is
// the live program of the case's `curriculum_id` only; `expect` is the
// sorted list of violated wire codes.

import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

const limits = await import('../lib/sub_track_limits.js');

const FIXTURE_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'test', 'fixtures', 'sub_track_limits');

function merge(into, fields) {
  const out = { ...into };
  for (const [k, v] of Object.entries(fields)) {
    if (v === null) delete out[k];
    else out[k] = v;
  }
  return out;
}

function runCase(base, c) {
  const rows = new Map(c.existing.map((e) => [e.id, merge(base, e.doc)]));
  const existing = [...rows].map(([id, data]) => ({ id, data }));
  const op = c.op;
  if (op.kind === 'set_program') {
    return limits.subTrackViolationCodes(limits.calendarProgramSetViolations({
      curriculumId: c.curriculum_id, programId: op.program_id, subTracks: existing,
    }));
  }
  const prior = op.kind === 'edit' ? rows.get(op.id) : null;
  const data = merge(prior ?? base, op.fields);
  return limits.subTrackViolationCodes([
    ...limits.subTrackIntentViolations(data),
    ...limits.subTrackLimitViolations({
      candidate: { id: op.id, data },
      prior,
      siblings: existing,
      today: c.today,
      calendarProgramId: data.curriculum_id === c.curriculum_id ? c.program_id : null,
    }),
  ]);
}

const files = readdirSync(FIXTURE_DIR).filter((f) => f.endsWith('.json')).sort();

describe('AD-45 shared fixtures (TypeScript validator)', () => {
  test('the suite exists and covers every server-side wire code', () => {
    const codes = new Set();
    let count = 0;
    for (const f of files) {
      for (const c of JSON.parse(readFileSync(join(FIXTURE_DIR, f), 'utf8')).cases) {
        count++;
        c.expect.forEach((x) => codes.add(x));
      }
    }
    assert.ok(count >= 40, `only ${count} cases`);
    assert.deepEqual([...codes].sort(), [
      'calendar_program_curriculum',
      'calendar_program_has_sub_tracks',
      'duplicate_ground',
      'non_positive_rate',
      'non_positive_weeks',
      'ongoing_limit',
      'school_year_duplicate_academic_year',
      'school_year_window_overlap',
      'window_reversed',
    ]);
  });

  for (const f of files) {
    const { base, cases } = JSON.parse(readFileSync(join(FIXTURE_DIR, f), 'utf8'));
    for (const c of cases) {
      test(`${f}: ${c.name}`, () => {
        assert.deepEqual(runCase(base, c), c.expect);
      });
    }
  }
});

describe('civilDateIn (AD-41 learner today)', () => {
  test('uses the learner time zone, falling back to UTC', () => {
    const now = new Date('2026-10-01T22:30:00Z');
    assert.equal(limits.civilDateIn('UTC', now), '2026-10-01');
    assert.equal(limits.civilDateIn('Asia/Jerusalem', now), '2026-10-02');
    assert.equal(limits.civilDateIn('America/New_York', now), '2026-10-01');
    assert.equal(limits.civilDateIn(undefined, now), '2026-10-01');
    assert.equal(limits.civilDateIn('Not/AZone', now), '2026-10-01');
  });
});
