// Shared callable-contract matrix for the governed tutor callables that are
// rerouted through writeWithChangeLog (sub-tracks AD-38 / AD-53, Story 1.10).
//
// Every rerouted callable must reject the same way and log the same
// privacy-safe `{entity, code}` line, because the checks live in the shared
// helper and in no callable of its own. Each cf_*.test.mjs that covers one of
// these callables calls `describeGovernedContract` once per callable and then
// adds its callable-specific happy-path tests.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  assertPrivacySafeRejectionLog,
  call,
  captureLogs,
  changeLog,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  seedActiveGrant,
  seedLearningGrant,
  seedProfile,
  strangerAuth,
  ulid,
} from './_cf_helpers.mjs';

/**
 * @param {string} name       exported callable name (e.g. 'tutorUpsertGoal').
 * @param {object} opts
 * @param {object} opts.goodArgs   a request that succeeds and writes one entry.
 * @param {string} opts.idParam    the request's target-id field.
 * @param {string} [opts.dataParam] the request's payload field (upserts only).
 * @param {string} opts.entity     the AD-38 entity logged on failure.
 * @param {() => Promise<void>} [opts.seed] extra fixture data (after profile).
 */
export function describeGovernedContract(name, { goodArgs, idParam, dataParam, entity, seed }) {
  describe(`${name} — governed callable contract`, () => {
    beforeEach(async () => {
      await clearFirestore();
      await seedProfile();
      if (seed) await seed();
    });

    const rejects = async (args, code, auth) => {
      const { error, logs } = await captureLogs(() => call(fns[name], args, auth));
      await expectHttpsError(Promise.reject(error), code);
      assertPrivacySafeRejectionLog(logs, { entity, code });
      assert.deepEqual(await changeLog(), [], 'a rejected call writes no change_log entry');
    };

    test('no auth → unauthenticated', async () => {
      await seedLearningGrant();
      await rejects(goodArgs, 'unauthenticated', null);
    });

    const shapeCases = [
      ['blank grantId', { grantId: '' }],
      ['blank ownerUid', { ownerUid: '' }],
      ['numeric profileId', { profileId: 5 }],
      [`blank ${idParam}`, { [idParam]: '' }],
      [`${idParam} containing a path separator`, { [idParam]: 'a/b' }],
      ['malformed actionId', { actionId: 'not-a-ulid' }],
    ];
    if (dataParam) {
      shapeCases.push([`${dataParam} is an array`, { [dataParam]: [1, 2] }]);
      shapeCases.push([`${dataParam} is null`, { [dataParam]: null }]);
      shapeCases.push([`${dataParam} has an unknown field`, {
        [dataParam]: { ...goodArgs[dataParam], not_a_storage_field: 'x' },
      }]);
    }
    for (const [label, patch] of shapeCases) {
      test(`bad payload (${label}) → invalid-argument`, async () => {
        await seedLearningGrant();
        await rejects({ ...goodArgs, ...patch }, 'invalid-argument');
      });
    }

    test('no grant → permission-denied', async () => {
      await rejects(goodArgs, 'permission-denied');
    });

    test('revoked grant → permission-denied', async () => {
      await seedLearningGrant({ state: 'revoked_by_parent' });
      await rejects(goodArgs, 'permission-denied');
    });

    test('legacy per-feature permissions without can_edit_learning → permission-denied', async () => {
      await seedActiveGrant({
        can_edit_goals: true, can_edit_stages: true, can_edit_study_days: true,
      });
      await rejects(goodArgs, 'permission-denied');
    });

    test('caller is not the grant tutor → permission-denied', async () => {
      await seedLearningGrant();
      await rejects(goodArgs, 'permission-denied', strangerAuth);
    });

    test('happy path writes one change_log entry; a replay of the same actionId returns it', async () => {
      await seedLearningGrant();
      const args = { ...goodArgs, actionId: ulid(500) };
      const first = await call(fns[name], args);
      assert.equal(first.success, true);
      assert.equal(first.action_id, ulid(500));
      assert.ok(first.change_ids.length >= 1);
      assert.ok(!Number.isNaN(Date.parse(first.at)), 'returns the server-stamped at');
      const replay = await call(fns[name], args);
      assert.equal(replay.replayed, true);
      assert.deepEqual(replay.change_ids, first.change_ids);
      assert.equal(replay.at, first.at);
      assert.equal((await changeLog()).length, first.change_ids.length);
      // Security audit only: who/what/when, no copied before/after values.
      const audit = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
      assert.equal(audit.size, 1);
      assert.equal(audit.docs[0].get('before_value'), null);
      assert.equal(audit.docs[0].get('after_value'), null);
    });
  });
}
