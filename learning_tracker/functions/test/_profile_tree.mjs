// DNI-491 (Story 1.29) AC-4 — seed and check a learner's data tree for the
// account and profile deletion tests (cf_deletes, cf_triggers).
//
// After the release that follows the AD-49 cutover, the per-profile data is
// the learning record (learning_events), sub_tracks, change_log, the
// points ledger and the AD-38 governed docs. Deletion stays a recursive
// delete of `users/{uid}` or of one `learner_profiles/{profileId}` subtree,
// never a per-collection sweep, so every collection seeded here must
// disappear with its root — and nothing outside that root may.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { db, profileRef, ulid } from './_cf_helpers.mjs';

/** One doc per per-profile collection the rules allow today. */
export const PROFILE_COLLECTIONS = Object.freeze({
  // The learning record and history (append-only; never client-deleted).
  learning_events: () => [ulid(1), { kind: 'learn', curriculum_id: 'c1', ref: 'Berakhot.2a' }],
  change_log: () => [ulid(2), { entity: 'subTrack', entity_id: ulid(3) }],
  points_ledger: () => [`pts_${ulid(1)}`, { points: 3, event_id: ulid(1) }],
  // AD-38 governed docs (removal is a tombstone; only account/profile
  // deletion removes them).
  sub_tracks: () => [ulid(3), { curriculum_id: 'c1', last_change_id: ulid(2) }],
  goals: () => ['g1', { curriculum_id: 'c1' }],
  curriculum_tracks: () => ['c1', { curriculum_id: 'c1', state: 'active' }],
  track_learning_order: () => ['c1_daf_Berakhot.2a', { curriculum_id: 'c1', user_sort_order: 1 }],
  profile_programs: () => ['c1', { curriculum_id: 'c1' }],
  study_day_configs: () => ['c1_1', { curriculum_id: 'c1', day_of_week: 1 }],
  stage_definitions: () => ['c1_1', { curriculum_id: 'c1', stage_order: 1 }],
  curriculum_scopes: () => ['s1', { curriculum_id: 'c1' }],
  // Other owner data under the profile.
  settings: () => ['c1', { curriculum_id: 'c1' }],
  preferences: () => ['ui_preferences', { theme: 'dark' }],
  import_metadata: () => ['c1', { curriculum_id: 'c1' }],
  point_configs: () => ['c1_1', { points: 2 }],
  reward_redemptions: () => [ulid(4), { reward_id: 'r1' }],
});

/**
 * Seeds the profile doc (unless [withRoot] is false: descendants of a
 * missing parent doc are still reachable by a recursive delete) and one doc
 * in every [PROFILE_COLLECTIONS] collection. Returns every seeded ref.
 */
export async function seedProfileTree(uid, profileId, { withRoot = true } = {}) {
  const root = profileRef(uid, profileId);
  const refs = [];
  if (withRoot) {
    await root.set({ display_name: `profile ${profileId}` });
    refs.push(root);
  }
  for (const [collection, make] of Object.entries(PROFILE_COLLECTIONS)) {
    const [id, data] = make();
    const ref = root.collection(collection).doc(id);
    await ref.set(data);
    refs.push(ref);
  }
  return refs;
}

/**
 * Seeds an account: the users/{uid} doc, its profile snapshot and a
 * diagnostic log, plus a full tree for each of [profileIds].
 */
export async function seedAccountTree(uid, profileIds) {
  const user = db.collection('users').doc(uid);
  await user.set({ display_name: `user ${uid}` });
  const snapshot = user.collection('profile').doc('data');
  await snapshot.set({ email: `${uid}@example.com` });
  const log = user.collection('diagnostic_logs').doc('d1');
  await log.set({ message: 'seeded' });
  const refs = [user, snapshot, log];
  for (const profileId of profileIds) {
    refs.push(...(await seedProfileTree(uid, profileId)));
  }
  return refs;
}

/** Every ref in [refs] is gone. */
export async function assertAllGone(refs, label) {
  const left = [];
  for (const ref of refs) if ((await ref.get()).exists) left.push(ref.path);
  assert.deepEqual(left, [], `${label}: these documents survived the delete`);
}

/** Every ref in [refs] still exists. */
export async function assertAllPresent(refs, label) {
  const missing = [];
  for (const ref of refs) if (!(await ref.get()).exists) missing.push(ref.path);
  assert.deepEqual(missing, [], `${label}: these documents were deleted`);
}

/**
 * The five collections the AD-49 cutover retired, read from R14 of the
 * retired-symbols inventory so no test spells them.
 */
export function retiredCollections() {
  const r14 = JSON.parse(readFileSync(
    new URL('../../tool/retired_symbols/R14.json', import.meta.url),
    'utf8',
  ));
  return r14.entries.filter((e) => e.kind === 'collection').map((e) => e.symbol);
}
