/**
 * Firestore security rules emulator test suite.
 *
 * Story 24.1 (DNI-316): Per-collection Firestore rules with field validators
 * and emulator test job.
 *
 * Covers:
 *  - completions: create-only, points [0,100], completedAt <= request.time
 *  - streak_events: create-only, createdAt <= request.time
 *  - learning_ledger: create-only, createdAt <= request.time
 *  - settings: create/update with field whitelist only
 *  - All collections: delete denied
 *  - Unauthenticated access denied
 *  - Cross-user access denied
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

// ── Constants ──────────────────────────────────────────────────────────────

const PROJECT_ID = 'learning-tracker-rules-test';
const UID = 'test-user-uid';
const OTHER_UID = 'other-user-uid';
const PROFILE_ID = '1';

// Base path for all subcollections used in this test suite.
const profilePath = `users/${UID}/learner_profiles/${PROFILE_ID}`;

// ── Test environment ───────────────────────────────────────────────────────

let testEnv;

beforeAll(async () => {
  // FIRESTORE_EMULATOR_HOST can be set by the caller (e.g. CI or firebase
  // emulators:exec) to override the default port.  Default: localhost:9090.
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:9090';
  const [host, portStr] = emulatorHost.split(':');
  const port = portStr ? parseInt(portStr, 10) : 9090;

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host,
      port,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ── Helpers ────────────────────────────────────────────────────────────────

/** Authenticated Firestore client for the test owner. */
function authedFirestore() {
  return testEnv.authenticatedContext(UID).firestore();
}

/** Authenticated Firestore client for a different user (cross-user). */
function otherUserFirestore() {
  return testEnv.authenticatedContext(OTHER_UID).firestore();
}

/** Unauthenticated Firestore client. */
function unauthFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

// Import firestore helpers lazily so they resolve after initializeTestEnvironment.
async function getFirestoreHelpers() {
  const { Timestamp } = await import('firebase/firestore');
  return { Timestamp };
}

// ── completions ────────────────────────────────────────────────────────────

describe('completions collection', () => {
  const collectionPath = `${profilePath}/completions`;

  test('owner can create with valid points and past completedAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    const docRef = db.collection(collectionPath).doc();
    await assertSucceeds(
      docRef.set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('owner can create with points = 0 (boundary)', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertSucceeds(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 0,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('owner can create with points = 100 (boundary)', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertSucceeds(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 100,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: points exceeds 100 (T1.3 regression)', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 999_999,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: points below 0', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: -1,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: future-dated completedAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('denied: unauthenticated create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = unauthFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: cross-user create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = otherUserFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: delete by owner', async () => {
    // Seed the doc through admin context so we can attempt deletion.
    const { Timestamp } = await getFirestoreHelpers();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(collectionPath).doc('doc1').set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      });
    });

    const db = authedFirestore();
    await assertFails(db.collection(collectionPath).doc('doc1').delete());
  });

  test('denied: update (immutable after create)', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(collectionPath).doc('doc1').set({
        curriculum_id: 'mishnayos',
        content_item_id: 'mishna-1',
        stage_id: 1,
        track_type: 'personal',
        points: 10,
        completedAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      });
    });

    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc('doc1').update({ points: 50 })
    );
  });
});

// ── streak_events ──────────────────────────────────────────────────────────

describe('streak_events collection', () => {
  const collectionPath = `${profilePath}/streak_events`;

  test('owner can create with past createdAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertSucceeds(
      db.collection(collectionPath).doc().set({
        event_type: 'streak_extended',
        streak_count: 5,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: future createdAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        event_type: 'streak_extended',
        streak_count: 5,
        createdAt: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('denied: unauthenticated create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = unauthFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        event_type: 'streak_extended',
        streak_count: 5,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: cross-user create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = otherUserFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        event_type: 'streak_extended',
        streak_count: 5,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: delete by owner', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(collectionPath).doc('ev1').set({
        event_type: 'streak_extended',
        streak_count: 5,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      });
    });

    const db = authedFirestore();
    await assertFails(db.collection(collectionPath).doc('ev1').delete());
  });
});

// ── learning_ledger ────────────────────────────────────────────────────────

describe('learning_ledger collection', () => {
  const collectionPath = `${profilePath}/learning_ledger`;

  test('owner can create with past createdAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertSucceeds(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        total_points: 50,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: future createdAt', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        total_points: 50,
        createdAt: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('denied: unauthenticated create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = unauthFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        total_points: 50,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: cross-user create', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    const db = otherUserFirestore();
    await assertFails(
      db.collection(collectionPath).doc().set({
        curriculum_id: 'mishnayos',
        total_points: 50,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('denied: delete by owner', async () => {
    const { Timestamp } = await getFirestoreHelpers();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(collectionPath).doc('led1').set({
        curriculum_id: 'mishnayos',
        total_points: 50,
        createdAt: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      });
    });

    const db = authedFirestore();
    await assertFails(db.collection(collectionPath).doc('led1').delete());
  });
});

// ── settings ───────────────────────────────────────────────────────────────

describe('settings collection', () => {
  const collectionPath = `${profilePath}/settings`;

  test('owner can create with whitelisted fields only', async () => {
    const db = authedFirestore();
    await assertSucceeds(
      db.collection(collectionPath).doc('mishnayos').set({
        hebrewTerms: true,
        useHebrewDate: false,
        curriculum_id: 'mishnayos',
        updated_at: new Date(),
      })
    );
  });

  test('owner can update with whitelisted fields only', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection(collectionPath)
        .doc('mishnayos')
        .set({ hebrewTerms: false, curriculum_id: 'mishnayos' });
    });

    const db = authedFirestore();
    await assertSucceeds(
      db
        .collection(collectionPath)
        .doc('mishnayos')
        .update({ hebrewTerms: true, updated_at: new Date() })
    );
  });

  test('denied: create with arbitrary non-whitelisted field', async () => {
    const db = authedFirestore();
    await assertFails(
      db.collection(collectionPath).doc('mishnayos').set({
        hebrewTerms: true,
        curriculum_id: 'mishnayos',
        injected_field: 'malicious',
      })
    );
  });

  test('denied: update with arbitrary non-whitelisted field', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection(collectionPath)
        .doc('mishnayos')
        .set({ hebrewTerms: false, curriculum_id: 'mishnayos' });
    });

    const db = authedFirestore();
    await assertFails(
      db
        .collection(collectionPath)
        .doc('mishnayos')
        .update({ arbitrary_key: 'value' })
    );
  });

  test('denied: unauthenticated write', async () => {
    const db = unauthFirestore();
    await assertFails(
      db
        .collection(collectionPath)
        .doc('mishnayos')
        .set({ hebrewTerms: true, curriculum_id: 'mishnayos' })
    );
  });

  test('denied: cross-user write', async () => {
    const db = otherUserFirestore();
    await assertFails(
      db
        .collection(collectionPath)
        .doc('mishnayos')
        .set({ hebrewTerms: true, curriculum_id: 'mishnayos' })
    );
  });

  test('denied: delete by owner', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection(collectionPath)
        .doc('mishnayos')
        .set({ hebrewTerms: false, curriculum_id: 'mishnayos' });
    });

    const db = authedFirestore();
    await assertFails(db.collection(collectionPath).doc('mishnayos').delete());
  });
});

// ── Generic delete-denied for remaining collections ────────────────────────

describe('delete denied across all collections', () => {
  const collections = ['bookmarks', 'goals', 'streak', 'notification_settings', 'gamification_settings'];

  for (const col of collections) {
    test(`delete denied in ${col}`, async () => {
      const colPath = `${profilePath}/${col}`;
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection(colPath).doc('doc1').set({ data: 'test' });
      });

      const db = authedFirestore();
      await assertFails(db.collection(colPath).doc('doc1').delete());
    });
  }
});

// ── Cross-user access denied ───────────────────────────────────────────────

describe('cross-user access denied', () => {
  test("other user cannot read owner's completions", async () => {
    const colPath = `${profilePath}/completions`;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(colPath).doc('doc1').set({ data: 'test' });
    });

    const db = otherUserFirestore();
    await assertFails(db.collection(colPath).doc('doc1').get());
  });

  test("other user cannot read owner's settings", async () => {
    const colPath = `${profilePath}/settings`;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection(colPath).doc('s1').set({ hebrewTerms: true });
    });

    const db = otherUserFirestore();
    await assertFails(db.collection(colPath).doc('s1').get());
  });
});

// ── Unauthenticated access denied ─────────────────────────────────────────

describe('unauthenticated access denied across all collections', () => {
  const collections = ['completions', 'streak_events', 'learning_ledger', 'settings', 'bookmarks'];

  for (const col of collections) {
    test(`unauthenticated read denied in ${col}`, async () => {
      const colPath = `${profilePath}/${col}`;
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await ctx.firestore().collection(colPath).doc('doc1').set({ data: 'test' });
      });

      const db = unauthFirestore();
      await assertFails(db.collection(colPath).doc('doc1').get());
    });
  }
});
