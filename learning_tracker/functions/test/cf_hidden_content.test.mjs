// Hidden-content callable authorization and payload contract.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import {
  GRANT,
  PARENT,
  PROFILE,
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  parentAuth,
  profileRef,
  seedActiveGrant,
  strangerAuth,
} from './_cf_helpers.mjs';

describe('setProfileHiddenContent', () => {
  const hiddenRefs = [
    'Niddah',
    'Jerusalem Talmud Niddah',
  ];

  beforeEach(async () => {
    await clearFirestore();
    await profileRef().set({ display_name: 'Child', mode: 'child', unrelated: 'preserved' });
  });

  test('owner can replace the child hidden-node list without changing other profile fields', async () => {
    const result = await call(fns.setProfileHiddenContent, {
      ownerUid: PARENT,
      profileId: PROFILE,
      hiddenRefs,
    }, parentAuth);

    assert.equal(result.success, true);
    assert.deepEqual((await profileRef().get()).data(), {
      display_name: 'Child',
      mode: 'child',
      unrelated: 'preserved',
      hidden_content_refs: hiddenRefs,
    });
  });

  test('an ungated legacy session id is ignored', async () => {
    const result = await call(fns.setProfileHiddenContent, {
      ownerUid: PARENT,
      profileId: PROFILE,
      hiddenRefs,
      parentSessionId: 'expired-or-malformed',
    }, parentAuth);

    assert.equal(result.success, true);
    assert.deepEqual((await profileRef().get()).get('hidden_content_refs'), hiddenRefs);
  });

  test('the rollout claim requires an active well-formed session id', async () => {
    const enforcedAuth = { uid: PARENT, token: { parent_session_enforced: true } };
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs,
        parentSessionId: 'expired-or-malformed',
      }, enforcedAuth),
      'invalid-argument',
    );
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs,
      }, enforcedAuth),
      'permission-denied',
    );
  });

  test('tutor with matching active grant can replace the list', async () => {
    await seedActiveGrant({});
    const result = await call(fns.setProfileHiddenContent, {
      ownerUid: PARENT,
      profileId: PROFILE,
      grantId: GRANT,
      hiddenRefs,
    });

    assert.equal(result.success, true);
    assert.deepEqual((await profileRef().get()).get('hidden_content_refs'), hiddenRefs);
    const audit = await db.collection('tutor_grants').doc(GRANT).collection('audit_log').get();
    assert.equal(audit.size, 1);
    assert.equal(audit.docs[0].get('action'), 'hidden_content_updated');
  });

  test('tutor cannot configure an adult profile', async () => {
    await seedActiveGrant({});
    await profileRef().update({ mode: 'adult' });
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        grantId: GRANT,
        hiddenRefs,
      }),
      'failed-precondition',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('tutor grant is bound to the caller, owner, and child profile', async () => {
    await seedActiveGrant({});
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        grantId: GRANT,
        hiddenRefs,
      }, strangerAuth),
      'permission-denied',
    );
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XZ',
        grantId: GRANT,
        hiddenRefs,
      }),
      'permission-denied',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('inactive or missing tutor grant is denied', async () => {
    await seedActiveGrant({}, { state: 'revoked_by_parent' });
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        grantId: GRANT,
        hiddenRefs,
      }),
      'permission-denied',
    );
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        grantId: 'missing-grant',
        hiddenRefs,
      }),
      'not-found',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('ownerUid must match the caller and profile must exist', async () => {
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: 'someone-else',
        profileId: PROFILE,
        hiddenRefs,
      }, parentAuth),
      'permission-denied',
    );
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XZ',
        hiddenRefs,
      }, parentAuth),
      'not-found',
    );
  });

  test('adult profiles cannot receive child hidden-content settings', async () => {
    await profileRef().update({ mode: 'adult' });
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs,
      }, parentAuth),
      'failed-precondition',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('rejects malformed, oversized, or unexpected payload fields', async () => {
    for (const invalid of [
      [null],
      [''],
      ['x'.repeat(501)],
      Array.from({ length: 501 }, (_, i) => `node-${i}`),
    ]) {
      await expectHttpsError(
        call(fns.setProfileHiddenContent, {
          ownerUid: PARENT,
          profileId: PROFILE,
          hiddenRefs: invalid,
        }, parentAuth),
        'invalid-argument',
      );
    }
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs,
        mode: 'adult',
      }, parentAuth),
      'invalid-argument',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('rejects a ref that is not present in the curriculum hierarchy assets', async () => {
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs: ['Not a real curriculum node'],
      }, parentAuth),
      'invalid-argument',
    );
    assert.equal((await profileRef().get()).get('hidden_content_refs'), undefined);
  });

  test('unauthenticated caller is denied', async () => {
    await expectHttpsError(
      call(fns.setProfileHiddenContent, {
        ownerUid: PARENT,
        profileId: PROFILE,
        hiddenRefs,
      }, null),
      'unauthenticated',
    );
  });
});
