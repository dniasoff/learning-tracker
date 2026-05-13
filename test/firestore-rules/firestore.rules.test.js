/**
 * Firestore security rules emulator test suite.
 *
 * Story 25.4 (DNI-325): Firestore v1 top-level collection layout +
 * per-collection security rules.
 *
 * Replaces the old nested `users/{uid}/` layout from Story 24.1 (DNI-316).
 *
 * Collections under test (all top-level):
 *
 * Snapshot collections (allow read, create, update with field whitelist; deny delete):
 *   accounts, learner_profiles, track_configs, bookmarks, settings
 *
 * Event collections (allow create only with validators; deny update + delete):
 *   completion_events, streak_events, learning_ledger
 *
 * Every collection has at least one allowed-case and one denied-case test.
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
const UID = 'testuid123';
const OTHER_UID = 'otheruserid';
const PROFILE_ID = '1';

// Deterministic doc IDs following the v1 convention.
const ACCOUNT_DOC   = UID;                                      // {uid}
const PROFILE_DOC   = `${UID}_${PROFILE_ID}`;                  // {uid}_{profileId}
const TRACK_DOC     = `${UID}_${PROFILE_ID}_mishnayos`;        // {uid}_{profileId}_{curriculumId}
const BOOKMARK_DOC  = `${UID}_${PROFILE_ID}_Mishnah_Berakhot-1-1`; // {uid}_{profileId}_{sefariaRef}
const SETTINGS_DOC  = `${UID}_${PROFILE_ID}`;                  // {uid}_{profileId}
const COMPLETION_DOC = `${UID}_${PROFILE_ID}_Mishnah_Berakhot-1-1_2_personal`;
const STREAK_DOC    = `${UID}_${PROFILE_ID}_streak_extended_20260513`;
const LEDGER_DOC    = `${UID}_${PROFILE_ID}_mishnayos_20260513`;

// ── Test environment ───────────────────────────────────────────────────────

let testEnv;

beforeAll(async () => {
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

function authedDb()      { return testEnv.authenticatedContext(UID).firestore(); }
function otherUserDb()   { return testEnv.authenticatedContext(OTHER_UID).firestore(); }
function unauthDb()      { return testEnv.unauthenticatedContext().firestore(); }

async function getTimestamp() {
  const { Timestamp } = await import('firebase/firestore');
  return Timestamp;
}

/** Seed a document bypassing security rules (admin context). */
async function seedDoc(collection, docId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection(collection).doc(docId).set(data);
  });
}

// ── accounts ───────────────────────────────────────────────────────────────

describe('accounts collection', () => {
  const col = 'accounts';

  test('[allow] owner can create own account doc with whitelisted fields', async () => {
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(ACCOUNT_DOC).set({
        uid: UID,
        email: 'user@example.com',
        display_name: 'Test User',
        created_at: new Date(),
        updated_at: new Date(),
        platform: 'android',
        app_version: '1.0.0',
      })
    );
  });

  test('[allow] owner can update own account doc', async () => {
    await seedDoc(col, ACCOUNT_DOC, { uid: UID, display_name: 'Old Name' });
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(ACCOUNT_DOC).update({
        display_name: 'New Name',
        updated_at: new Date(),
      })
    );
  });

  test('[allow] owner can read own account doc', async () => {
    await seedDoc(col, ACCOUNT_DOC, { uid: UID });
    const db = authedDb();
    await assertSucceeds(db.collection(col).doc(ACCOUNT_DOC).get());
  });

  test('[deny] create with non-whitelisted field', async () => {
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(ACCOUNT_DOC).set({
        uid: UID,
        injected_field: 'evil',
      })
    );
  });

  test('[deny] owner cannot delete account doc', async () => {
    await seedDoc(col, ACCOUNT_DOC, { uid: UID });
    const db = authedDb();
    await assertFails(db.collection(col).doc(ACCOUNT_DOC).delete());
  });

  test('[deny] cross-user cannot read another account', async () => {
    await seedDoc(col, ACCOUNT_DOC, { uid: UID });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(ACCOUNT_DOC).get());
  });

  test('[deny] unauthenticated cannot create account', async () => {
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(ACCOUNT_DOC).set({ uid: UID })
    );
  });
});

// ── learner_profiles ───────────────────────────────────────────────────────

describe('learner_profiles collection', () => {
  const col = 'learner_profiles';

  test('[allow] owner can create profile with whitelisted fields', async () => {
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(PROFILE_DOC).set({
        uid: UID,
        profile_id: 1,
        display_name: 'Alice',
        avatar_url: null,
        created_at: new Date(),
        updated_at: new Date(),
        is_child_mode: false,
      })
    );
  });

  test('[allow] owner can update profile', async () => {
    await seedDoc(col, PROFILE_DOC, { uid: UID, profile_id: 1, display_name: 'Old' });
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(PROFILE_DOC).update({
        display_name: 'Alice',
        updated_at: new Date(),
      })
    );
  });

  test('[allow] owner can read own profile', async () => {
    await seedDoc(col, PROFILE_DOC, { uid: UID, profile_id: 1 });
    const db = authedDb();
    await assertSucceeds(db.collection(col).doc(PROFILE_DOC).get());
  });

  test('[deny] create with non-whitelisted field', async () => {
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(PROFILE_DOC).set({
        uid: UID,
        profile_id: 1,
        secret_field: 'leaked',
      })
    );
  });

  test('[deny] delete denied', async () => {
    await seedDoc(col, PROFILE_DOC, { uid: UID, profile_id: 1 });
    const db = authedDb();
    await assertFails(db.collection(col).doc(PROFILE_DOC).delete());
  });

  test('[deny] cross-user cannot read another profile', async () => {
    await seedDoc(col, PROFILE_DOC, { uid: UID, profile_id: 1 });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(PROFILE_DOC).get());
  });

  test('[deny] cross-user cannot create a doc owned by another uid', async () => {
    const db = otherUserDb();
    // Attempting to write a doc whose ID starts with UID (not OTHER_UID)
    await assertFails(
      db.collection(col).doc(PROFILE_DOC).set({ uid: UID, profile_id: 1 })
    );
  });
});

// ── completion_events ──────────────────────────────────────────────────────

describe('completion_events collection', () => {
  const col = 'completion_events';

  test('[allow] owner can create with valid points and past completed_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 10,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[allow] owner can create with points = 0 (lower boundary)', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(COMPLETION_DOC + '_b0').set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 0,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[allow] owner can create with points = 100 (upper boundary)', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(COMPLETION_DOC + '_b100').set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 100,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] points exceeds 100', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 999_999,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] points below 0', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: -1,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] future-dated completed_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 10,
        completed_at: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('[deny] uid field does not match auth uid', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    // Doc ID starts with UID (passes doc-id check), but uid field is OTHER_UID
    await assertFails(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: OTHER_UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        stage_id: 2,
        track_type: 'personal',
        points: 10,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] update is not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, COMPLETION_DOC, {
      uid: UID, profile_id: 1, points: 10,
      completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(COMPLETION_DOC).update({ points: 50 }));
  });

  test('[deny] delete is not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, COMPLETION_DOC, {
      uid: UID, profile_id: 1, points: 10,
      completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(COMPLETION_DOC).delete());
  });

  test('[deny] unauthenticated create', async () => {
    const Timestamp = await getTimestamp();
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(COMPLETION_DOC).set({
        uid: UID,
        profile_id: 1,
        points: 10,
        completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] cross-user read', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, COMPLETION_DOC, {
      uid: UID, profile_id: 1, points: 10,
      completed_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(COMPLETION_DOC).get());
  });
});

// ── streak_events ──────────────────────────────────────────────────────────

describe('streak_events collection', () => {
  const col = 'streak_events';

  test('[allow] owner can create with past created_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(STREAK_DOC).set({
        uid: UID,
        profile_id: 1,
        event_type: 'streak_extended',
        streak_count: 5,
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] future created_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(STREAK_DOC).set({
        uid: UID,
        profile_id: 1,
        event_type: 'streak_extended',
        streak_count: 5,
        created_at: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('[deny] uid field mismatch', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(STREAK_DOC).set({
        uid: OTHER_UID,
        profile_id: 1,
        event_type: 'streak_extended',
        streak_count: 5,
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] update not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, STREAK_DOC, {
      uid: UID, profile_id: 1, event_type: 'streak_extended',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(STREAK_DOC).update({ streak_count: 99 }));
  });

  test('[deny] delete not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, STREAK_DOC, {
      uid: UID, profile_id: 1, event_type: 'streak_extended',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(STREAK_DOC).delete());
  });

  test('[deny] unauthenticated create', async () => {
    const Timestamp = await getTimestamp();
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(STREAK_DOC).set({
        uid: UID,
        profile_id: 1,
        event_type: 'streak_extended',
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] cross-user read', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, STREAK_DOC, {
      uid: UID, profile_id: 1, event_type: 'streak_extended',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(STREAK_DOC).get());
  });
});

// ── learning_ledger ────────────────────────────────────────────────────────

describe('learning_ledger collection', () => {
  const col = 'learning_ledger';

  test('[allow] owner can create with past created_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(LEDGER_DOC).set({
        uid: UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        total_points: 50,
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] future created_at', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(LEDGER_DOC).set({
        uid: UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        total_points: 50,
        created_at: Timestamp.fromDate(new Date(Date.now() + 86_400_000)),
      })
    );
  });

  test('[deny] uid field mismatch', async () => {
    const Timestamp = await getTimestamp();
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(LEDGER_DOC).set({
        uid: OTHER_UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        total_points: 50,
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] update not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, LEDGER_DOC, {
      uid: UID, profile_id: 1, curriculum_id: 'mishnayos',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(LEDGER_DOC).update({ total_points: 999 }));
  });

  test('[deny] delete not allowed', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, LEDGER_DOC, {
      uid: UID, profile_id: 1, curriculum_id: 'mishnayos',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = authedDb();
    await assertFails(db.collection(col).doc(LEDGER_DOC).delete());
  });

  test('[deny] unauthenticated create', async () => {
    const Timestamp = await getTimestamp();
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(LEDGER_DOC).set({
        uid: UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      })
    );
  });

  test('[deny] cross-user read', async () => {
    const Timestamp = await getTimestamp();
    await seedDoc(col, LEDGER_DOC, {
      uid: UID, profile_id: 1, curriculum_id: 'mishnayos',
      created_at: Timestamp.fromDate(new Date(Date.now() - 60_000)),
    });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(LEDGER_DOC).get());
  });
});

// ── track_configs ──────────────────────────────────────────────────────────

describe('track_configs collection', () => {
  const col = 'track_configs';

  test('[allow] owner can create with whitelisted fields', async () => {
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(TRACK_DOC).set({
        uid: UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        track_type: 'personal',
        learning_order: 'sequential',
        stage_id: 1,
        is_active: true,
        updated_at: new Date(),
      })
    );
  });

  test('[allow] owner can update with whitelisted fields', async () => {
    await seedDoc(col, TRACK_DOC, { uid: UID, profile_id: 1, curriculum_id: 'mishnayos', is_active: false });
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(TRACK_DOC).update({ is_active: true, updated_at: new Date() })
    );
  });

  test('[allow] owner can read own track config', async () => {
    await seedDoc(col, TRACK_DOC, { uid: UID, profile_id: 1, curriculum_id: 'mishnayos' });
    const db = authedDb();
    await assertSucceeds(db.collection(col).doc(TRACK_DOC).get());
  });

  test('[deny] create with non-whitelisted field', async () => {
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(TRACK_DOC).set({
        uid: UID,
        profile_id: 1,
        curriculum_id: 'mishnayos',
        injected_payload: 'evil',
      })
    );
  });

  test('[deny] delete not allowed', async () => {
    await seedDoc(col, TRACK_DOC, { uid: UID, profile_id: 1, curriculum_id: 'mishnayos' });
    const db = authedDb();
    await assertFails(db.collection(col).doc(TRACK_DOC).delete());
  });

  test('[deny] cross-user read', async () => {
    await seedDoc(col, TRACK_DOC, { uid: UID, profile_id: 1, curriculum_id: 'mishnayos' });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(TRACK_DOC).get());
  });

  test('[deny] unauthenticated write', async () => {
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(TRACK_DOC).set({ uid: UID, profile_id: 1, curriculum_id: 'mishnayos' })
    );
  });
});

// ── bookmarks ──────────────────────────────────────────────────────────────

describe('bookmarks collection', () => {
  const col = 'bookmarks';

  test('[allow] owner can create with whitelisted fields', async () => {
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(BOOKMARK_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        curriculum_id: 'mishnayos',
        stage_id: 2,
        updated_at: new Date(),
      })
    );
  });

  test('[allow] owner can update bookmark', async () => {
    await seedDoc(col, BOOKMARK_DOC, { uid: UID, profile_id: 1, sefaria_ref: 'Mishnah_Berakhot.1.1', stage_id: 1 });
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(BOOKMARK_DOC).update({ stage_id: 2, updated_at: new Date() })
    );
  });

  test('[allow] owner can read own bookmark', async () => {
    await seedDoc(col, BOOKMARK_DOC, { uid: UID, profile_id: 1, sefaria_ref: 'Mishnah_Berakhot.1.1' });
    const db = authedDb();
    await assertSucceeds(db.collection(col).doc(BOOKMARK_DOC).get());
  });

  test('[deny] create with non-whitelisted field', async () => {
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(BOOKMARK_DOC).set({
        uid: UID,
        profile_id: 1,
        sefaria_ref: 'Mishnah_Berakhot.1.1',
        malicious_extra: true,
      })
    );
  });

  test('[deny] delete not allowed', async () => {
    await seedDoc(col, BOOKMARK_DOC, { uid: UID, profile_id: 1 });
    const db = authedDb();
    await assertFails(db.collection(col).doc(BOOKMARK_DOC).delete());
  });

  test('[deny] cross-user cannot read another bookmark', async () => {
    await seedDoc(col, BOOKMARK_DOC, { uid: UID, profile_id: 1 });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(BOOKMARK_DOC).get());
  });

  test('[deny] unauthenticated write', async () => {
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(BOOKMARK_DOC).set({ uid: UID, profile_id: 1, sefaria_ref: 'x' })
    );
  });
});

// ── settings ───────────────────────────────────────────────────────────────

describe('settings collection', () => {
  const col = 'settings';

  test('[allow] owner can create with whitelisted fields', async () => {
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(SETTINGS_DOC).set({
        uid: UID,
        profile_id: 1,
        hebrew_terms: true,
        use_hebrew_date: false,
        curriculum_id: 'mishnayos',
        updated_at: new Date(),
        daily_goal: 5,
        review_enabled: true,
        chazara_interval: 7,
        show_points: true,
        track_type: 'personal',
      })
    );
  });

  test('[allow] owner can update with whitelisted fields', async () => {
    await seedDoc(col, SETTINGS_DOC, { uid: UID, profile_id: 1, hebrew_terms: false });
    const db = authedDb();
    await assertSucceeds(
      db.collection(col).doc(SETTINGS_DOC).update({ hebrew_terms: true, updated_at: new Date() })
    );
  });

  test('[allow] owner can read own settings', async () => {
    await seedDoc(col, SETTINGS_DOC, { uid: UID, profile_id: 1 });
    const db = authedDb();
    await assertSucceeds(db.collection(col).doc(SETTINGS_DOC).get());
  });

  test('[deny] create with non-whitelisted field', async () => {
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(SETTINGS_DOC).set({
        uid: UID,
        profile_id: 1,
        injected_field: 'malicious',
      })
    );
  });

  test('[deny] update with non-whitelisted field', async () => {
    await seedDoc(col, SETTINGS_DOC, { uid: UID, profile_id: 1, hebrew_terms: false });
    const db = authedDb();
    await assertFails(
      db.collection(col).doc(SETTINGS_DOC).update({ arbitrary_key: 'hacked' })
    );
  });

  test('[deny] delete not allowed', async () => {
    await seedDoc(col, SETTINGS_DOC, { uid: UID, profile_id: 1 });
    const db = authedDb();
    await assertFails(db.collection(col).doc(SETTINGS_DOC).delete());
  });

  test('[deny] cross-user cannot read another user settings', async () => {
    await seedDoc(col, SETTINGS_DOC, { uid: UID, profile_id: 1 });
    const db = otherUserDb();
    await assertFails(db.collection(col).doc(SETTINGS_DOC).get());
  });

  test('[deny] unauthenticated write', async () => {
    const db = unauthDb();
    await assertFails(
      db.collection(col).doc(SETTINGS_DOC).set({ uid: UID, profile_id: 1, hebrew_terms: true })
    );
  });
});
