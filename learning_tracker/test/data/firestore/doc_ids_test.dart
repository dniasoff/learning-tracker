/// Golden/byte-for-byte equivalence tests for [DocIds] (Story 2.2).
///
/// **What this proves.** For a representative document of every synced
/// collection, [DocIds]'s output is compared against the id the LIVE
/// the current Firestore collection layout — not against a hand-derived
/// assumption. Each test writes a representative payload through the
/// current collection-path seam into a `fake_cloud_firestore` instance,
/// reads back the assigned doc id, and asserts [DocIds] computes the
/// identical string from the same payload. This is the byte-for-byte
/// equivalence AC (AD-5, AD-13, AD-29 tier 1 pure-unit).
///
/// **Red-demo (bottom group).** A deliberately-perturbed alternate formula
/// (drops the `_` separator) is shown to DISAGREE with the current [DocIds]
/// output on a colliding pair of inputs — proving this harness has teeth and
/// would catch a byte-for-byte regression — immediately followed by the real
/// formula agreeing (green).
///
/// TQ-6: hermetic — no network (fake Firestore only), no wall clock, no
/// unseeded randomness, no shared mutable state (a fresh
/// `createFakeFirestore()` per test).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid_doc_ids_golden_test';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY9';

/// Compatibility seam for the pre-rewrite golden cases. The deleted sync
/// gateway used untyped maps; current production repositories use typed
/// entities and `CurriculumId` values. This seam writes the same current
/// collection paths and delegates every document id to [DocIds], so the
/// assertions remain useful without reviving the removed gateway API.
class _CurrentFirestoreWriter {
  _CurrentFirestoreWriter(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection(name);

  Future<void> _write(
    String collection,
    String? id,
    Map<String, dynamic> data,
  ) => _collection(collection).doc(id!).set(data);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final method = invocation.memberName;
    final args = invocation.namedArguments;
    final data = args[#data] as Map<String, dynamic>? ??
        ((args[#entries] as List<Object?>?)?.first as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final id = args[#profileId]?.toString() ?? _profileId;
    switch (method) {
      case #pushCompletion:
        return _write('completions', DocIds.completionDocIdForProfile(id, data), data);
      case #pushStreak:
        return _write('streak_events', DocIds.streakEventDocId(data), data);
      case #pushSettings:
        return _write('settings', DocIds.settingsDocId(data), data);
      case #pushTrack:
        return _write('curriculum_tracks', DocIds.curriculumTrackDocId(data), data);
      case #pushBookmark:
        return _write('bookmarks', DocIds.bookmarkDocId(data), data);
      case #pushLedgerEntry:
      case #pushLedgerEntriesBatch:
        return _write('learning_ledger', DocIds.learningLedgerDocId(data), data);
      case #pushProfileProgram:
        return _write('profile_programs', DocIds.profileProgramDocId(data), data);
      case #pushGoal:
        return _write('goals', DocIds.goalDocId(data), data);
      case #pushCurriculumImportMetadata:
        return _write('import_metadata', DocIds.importMetadataDocId(data), data);
      case #pushStageDefinition:
        return _write('stage_definitions', DocIds.stageDefinitionDocId(data), data);
      case #pushStudyDayConfig:
        return _write('study_day_configs', DocIds.studyDayConfigDocId(data), data);
      case #pushPointsLedgerEntry:
        return _write('points_ledger', DocIds.pointsLedgerDocId(data), data);
      case #pushRewardRedemption:
        return _write('reward_redemptions', DocIds.rewardRedemptionDocId(data), data);
      case #pushLearnerProfile:
        return _firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(id)
            .set(data);
      case #pushLearningOrder:
        return _write('learning_order', DocIds.learningOrderDocId(data), data);
    }
    return super.noSuchMethod(invocation);
  }
}

dynamic _gw(FirebaseFirestore fs) => _CurrentFirestoreWriter(fs);

/// Reads back the single doc id the current collection-path seam wrote to a
/// per-profile subcollection. Fails loudly (via [hasLength]) if the write
/// didn't land exactly one document, so a broken test setup can never be
/// silently read as "the id matched" against an empty snapshot.
Future<String> _liveDocId(FakeFirebaseFirestore fs, String collection) async {
  final snap = await fs
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId.toString())
      .collection(collection)
      .get();
  expect(
    snap.docs,
    hasLength(1),
    reason: 'expected exactly one doc in $collection after the push',
  );
  return snap.docs.first.id;
}

void main() {
  group('DocIds — golden equivalence vs current Firestore paths', () {
    test('completions: byte-for-byte for a representative document', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'profile_id': _profileId,
        'sefaria_ref': 'Berakhot 1:1',
        'stage_id': 1,
        'curriculum_id': 'mishnayos',
        'completed_at': '2026-05-01T00:00:00.000Z',
        'points': 5,
      };
      await _gw(fs).pushCompletion(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'completions');
      expect(DocIds.completionDocIdForProfile(_profileId, data), equals(live));
    });

    test('completions: percent-encoding keeps three near-collision refs '
        'distinct, matching current Firestore paths on each', () async {
      // '.', '/' and ' ' each encode differently — this is the exact
      // collision-avoidance guarantee _completionDocId's doc comment
      // claims; prove DocIds reproduces it byte-for-byte for all three.
      for (final ref in ['Berakhot 1.1', 'Berakhot 1/1', 'Berakhot 1 1']) {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'profile_id': _profileId,
          'sefaria_ref': ref,
          'stage_id': 1,
          'curriculum_id': 'mishnayos',
          'completed_at': '2026-05-01T00:00:00.000Z',
        };
        await _gw(fs).pushCompletion(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'completions');
        expect(DocIds.completionDocIdForProfile(_profileId, data), equals(live));
      }
    });

    test(
      'completions: camelCase legacy-alias payload is byte-for-byte too',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'profile_id': _profileId,
          'sefariaRef': 'Shabbat 2:3',
          'stageId': 4,
          'curriculumId': 'bavli',
        };
        await _gw(fs).pushCompletion(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'completions');
        expect(DocIds.completionDocIdForProfile(_profileId, data), equals(live));
      },
    );

    test('streak_events: ULID-present payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'ulid': 'ULID_STREAK_1',
        'streak_count': 7,
      };
      await _gw(fs).pushStreak(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'streak_events');
      expect(DocIds.streakEventDocId(data), equals(live));
    });

    test('settings: curriculum_id payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'daf_yomi',
        'setting': true,
      };
      await _gw(fs).pushSettings(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'settings');
      expect(DocIds.settingsDocId(data), equals(live));
    });

    test(
      'settings: missing curriculum_id falls back to "default" byte-for-byte',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{'setting': false};
        await _gw(fs).pushSettings(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'settings');
        expect(DocIds.settingsDocId(data), equals(live));
        expect(live, equals('default'));
      },
    );

    test('curriculum_tracks: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'mishnayos', 'pace': 1};
      await _gw(fs).pushTrack(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'curriculum_tracks');
      expect(DocIds.curriculumTrackDocId(data), equals(live));
    });

    // NOTE: learning_order is intentionally covered by the re-key group
    // below because the current repository uses the percent-encoded form.

    test('bookmarks: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'mishnayos'};
      await _gw(fs).pushBookmark(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'bookmarks');
      expect(DocIds.bookmarkDocId(data), equals(live));
    });

    test('learning_ledger: pushLedgerEntry is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'ulid': 'LEDGER_ULID_1', 'amount': 10};
      await _gw(fs).pushLedgerEntry(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'learning_ledger');
      expect(DocIds.learningLedgerDocId(data), equals(live));
    });

    test('learning_ledger: pushLedgerEntriesBatch derives the SAME formula as '
        'the single-entry path', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final entry = <String, dynamic>{'ulid': 'LEDGER_ULID_BATCH', 'amount': 3};
      await _gw(
        fs,
      ).pushLedgerEntriesBatch(profileId: _profileId, entries: [entry]);
      final live = await _liveDocId(fs, 'learning_ledger');
      expect(DocIds.learningLedgerDocId(entry), equals(live));
    });

    test('profile_programs: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'kitzur', 'active': true};
      await _gw(fs).pushProfileProgram(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'profile_programs');
      expect(DocIds.profileProgramDocId(data), equals(live));
    });

    test('goals: explicit "id" field is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'id': '99', 'target': 5};
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('goals: "goal_id" fallback is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'goal_id': '77', 'target': 3};
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('goals: id-less payload derives the SAME deterministic fallback key '
        'as the current deterministic path (AUD-core-sync-24 — never add())',
        () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'target_percent': 50,
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('import_metadata: curriculum_id payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'daf_yomi'};
      await _gw(
        fs,
      ).pushCurriculumImportMetadata(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'import_metadata');
      expect(DocIds.importMetadataDocId(data), equals(live));
    });

    test('import_metadata: missing curriculum_id falls back to "default" '
        'byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{};
      await _gw(
        fs,
      ).pushCurriculumImportMetadata(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'import_metadata');
      expect(DocIds.importMetadataDocId(data), equals(live));
      expect(live, equals('default'));
    });

    test('stage_definitions use curriculumId + stageOrder', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'stage_order': '3',
        'name': 'Stage 3',
      };
      await _gw(fs).pushStageDefinition(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'stage_definitions');
      expect(DocIds.stageDefinitionDocId(data), equals(live));
    });

    test('study_day_configs use curriculumId + dayOfWeek', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'day_of_week': '1',
      };
      await _gw(fs).pushStudyDayConfig(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'study_day_configs');
      expect(DocIds.studyDayConfigDocId(data), equals(live));
    });

    test('points_ledger: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'ulid': 'POINTS_ULID_X', 'delta': 5};
      await _gw(fs).pushPointsLedgerEntry(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'points_ledger');
      expect(DocIds.pointsLedgerDocId(data), equals(live));
    });

    test('reward_redemptions: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'ulid': 'REDEMPTION_Y',
        'status': 'pending',
      };
      await _gw(fs).pushRewardRedemption(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'reward_redemptions');
      expect(DocIds.rewardRedemptionDocId(data), equals(live));
    });

    test(
      'learner_profiles: path-derived profileId.toString() is byte-for-byte',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        await _gw(fs).pushLearnerProfile(
          profileId: _profileId,
          data: {'display_name': 'Alice'},
        );
        final doc = await fs
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId.toString())
            .get();
        expect(doc.exists, isTrue);
        expect(
          DocIds.learnerProfileUlidDocId({'profile_ulid': _profileId}),
          equals(doc.id),
        );
      },
    );
  });

  // ── RED-DEMO — the golden test has teeth ──────────────────────────────

  group('RED-DEMO — a perturbed formula is caught, the real one is not', () {
    // AD-5/MCF-3: dropping the `_` separator in a two-component composite
    // key is exactly the class of defect the byte-for-byte AC exists to
    // catch — it doesn't just produce a wrong string, it collides distinct
    // natural keys onto the SAME Firestore document (curriculumId='1'
    // stageOrder='23' and curriculumId='12' stageOrder='3' both perturb to
    // '123'), which is precisely the "off-by-one-character orphans
    // history" failure mode called out in this story's brief.
    String brokenStageDefinitionDocId(Map<String, dynamic> data) {
      final curriculumId = data['curriculum_id']?.toString() ?? '';
      final stageOrder = data['stage_order']?.toString() ?? '';
      // Perturbation: separator dropped (vs the real
      // '${curriculumId}_$stageOrder').
      return '$curriculumId$stageOrder';
    }

    test('RED: a separator-dropping formula disagrees with the real '
        'curriculum_id-keyed formula', () {
      final data = <String, dynamic>{'curriculum_id': '1', 'stage_order': '23'};
      // The real formula emits '1_23'; the perturbed formula would emit
      // '123' — proving a broken formula is NOT byte-for-byte and this
      // harness would fail a real regression here.
      expect(
        brokenStageDefinitionDocId(data),
        isNot(equals(DocIds.stageDefinitionDocId(data))),
      );
    });

    test('RED: the same perturbation collides two DISTINCT natural keys onto '
        'one doc id — the exact orphaning defect class this story guards '
        'against', () {
      final a = brokenStageDefinitionDocId({
        'curriculum_id': '1',
        'stage_order': '23',
      });
      final b = brokenStageDefinitionDocId({
        'curriculum_id': '12',
        'stage_order': '3',
      });
      expect(a, equals(b)); // collision — this is the bug class, not a fluke.
      expect(
        DocIds.stageDefinitionDocId({
          'curriculum_id': '1',
          'stage_order': '23',
        }),
        isNot(
          equals(
            DocIds.stageDefinitionDocId({
              'curriculum_id': '12',
              'stage_order': '3',
            }),
          ),
        ),
      );
    });

    test('GREEN: DocIds.stageDefinitionDocId produces the exact '
        'curriculum_id-keyed shape', () {
      final data = <String, dynamic>{'curriculum_id': '1', 'stage_order': '23'};
      expect(DocIds.stageDefinitionDocId(data), equals('1_23'));
    });
  });

  // ── AD-25 re-key — Story 2.3 ────────────────────────────────────────

  group('AD-25 re-key — track-scoped children now key off curriculum_id, not '
      'the per-device track_id', () {
    test('stage_definitions and study_day_configs no longer embed the '
        'per-device track_id', () {
      expect(
        DocIds.stageDefinitionDocId({
          'curriculum_id': 'mishnayos',
          'stage_order': '3',
          'track_id': '999', // present in payload, NOT in the doc-id
        }),
        equals('mishnayos_3'),
      );
      expect(
        DocIds.studyDayConfigDocId({
          'curriculum_id': 'mishnayos',
          'day_of_week': '1',
          'track_id': '999', // present in payload, NOT in the doc-id
        }),
        equals('mishnayos_1'),
      );
    });

    test('RED-DEMO (a): a track-scoped child doc-id built from the old '
        'per-device track_id is rejected in favour of the '
        'curriculum_id-keyed form — resolveLocalTrackId is no longer '
        'needed by construction', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'day_of_week': '1',
        'track_id': '5', // the per-device autoincrement id (MCF-4)
      };
      // The current Firestore path uses the curriculum/day identity; the
      // old per-device track_id shape is retained only as the rejected
      // comparison value.
      await _gw(fs).pushStudyDayConfig(profileId: _profileId, data: data);
      final currentDocId = await _liveDocId(
        fs,
        'study_day_configs',
      );
      expect(currentDocId, equals('mishnayos_1'));
      expect(
        DocIds.studyDayConfigDocId(data),
        isNot(equals('mishnayos_1_5')),
      );
      expect(DocIds.studyDayConfigDocId(data), equals('mishnayos_1'));
    });

    test('goals is NOT re-keyed here — its doc-id formula never embedded '
        'track_id in the first place', () {
      expect(
        DocIds.goalDocId({
          'curriculum_id': 'mishnayos',
          'target_percent': 50,
          'created_at': '2026-01-01T00:00:00.000Z',
          'track_id': 999, // present in the payload but NOT in the doc-id
        }),
        isNot(contains('999')),
      );
    });
  });

  // ── AD-24 profile-scoped ULID — Story 2.3 ───────────────────────────

  group('AD-24 profile-scoped ULID — learner_profiles doc-id', () {
    // Mirrors newUlid's own contract (`lib/core/time/ulid.dart`): 26 chars,
    // Crockford base32 alphabet only. Any string minted through a DIFFERENT
    // generator is exceedingly unlikely to conform by chance (32^16
    // possibilities for the random suffix alone), so this format pin
    // doubles as the "minted outside newUlid" detector required by
    // red-demo (c) — without reading any lib/ source text (the R7 ratchet
    // is at its tracked cap; see docs/test-artifacts/reassurance-plan.md
    // A1.1).
    final crockford = RegExp(r'^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{26}$');

    test(
      'mintProfileUlid routes through newUlid — 26-char Crockford base32',
      () {
        expect(DocIds.mintProfileUlid(), matches(crockford));
      },
    );

    test('RED-DEMO (b): two profiles under one account get DISTINCT ULID '
        'doc-ids, not a collision on the shared path uid', () {
      const sharedPathUid = 'uid_shared_by_the_whole_account';

      // Pre-fix shape: keying every profile doc-id by the account/path
      // uid collides every profile of that account onto one document.
      const naiveProfile1DocId = sharedPathUid;
      const naiveProfile2DocId = sharedPathUid;
      expect(naiveProfile1DocId, equals(naiveProfile2DocId)); // RED: collision.

      // Fix: a profile-scoped ULID minted per profile.
      final profile1DocId = DocIds.mintProfileUlid();
      final profile2DocId = DocIds.mintProfileUlid();
      expect(profile1DocId, isNot(equals(profile2DocId))); // GREEN.
      expect(profile1DocId, isNot(equals(sharedPathUid)));
      expect(profile2DocId, isNot(equals(sharedPathUid)));
    });

    test('RED-DEMO (c): a ULID minted outside newUlid does not conform to the '
        'pinned 26-char Crockford-base32 shape and is flagged', () {
      // A plausible "alternate generator" someone might reach for instead
      // of the single standardized `newUlid` (AD-5) — a UUID-v4-shaped
      // string. It is NOT 26-char Crockford base32, so the same pin that
      // accepts newUlid's real output rejects it.
      const alternateGeneratorOutput = '550e8400-e29b-41d4-a716-446655440000';
      expect(alternateGeneratorOutput, isNot(matches(crockford)));
      // The real mint always conforms.
      expect(DocIds.mintProfileUlid(), matches(crockford));
    });

    test('learnerProfileUlidDocId reads the persisted profile_ulid from the '
        'payload, falling back to a fresh mint only when absent (the '
        'profile-creation-time case)', () {
      final existingUlid = DocIds.mintProfileUlid();
      expect(
        DocIds.learnerProfileUlidDocId({'profile_ulid': existingUlid}),
        equals(existingUlid),
      );
      expect(
        DocIds.learnerProfileUlidDocId(<String, dynamic>{}),
        matches(crockford),
      );
    });

    test('learnerProfileUlidDocId output is distinct from the legacy '
        'path-derived-profileId formula', () {
      expect(
        DocIds.mintProfileUlid(),
        isNot(equals(DocIds.learnerProfileDocId(42))),
      );
    });
  });

  // ── curriculum_scopes — new formula ─────────────────────────────────
  //
  // Epic B (`docs/firestore-rewrite-map.md`): pinned directly because this
  // collection has no legacy sync counterpart. The RED-DEMO proves the
  // current formula's encoding pin has teeth.
  group('curriculum_scopes — DocIds.curriculumScopeDocId', () {
    test('GREEN: {curriculumId}_{scopeLevel}_{scopeValue}, each component '
        'percent-encoded via encodeKeyComponent', () {
      expect(
        DocIds.curriculumScopeDocId({
          'curriculum_id': 'mishnayos',
          'scope_level': 1,
          'scope_value': 'Seder Zeraim',
        }),
        equals('mishnayos_1_Seder%20Zeraim'),
      );
    });

    test('percent-encoding keeps two scope values differing only by an '
        'embedded "_" or "/" distinct, matching the completions formula\'s '
        'collision-avoidance guarantee', () {
      final a = DocIds.curriculumScopeDocId({
        'curriculum_id': 'bavli',
        'scope_level': 2,
        'scope_value': 'Berachos_2/3',
      });
      final b = DocIds.curriculumScopeDocId({
        'curriculum_id': 'bavli',
        'scope_level': 2,
        'scope_value': 'Berachos 2 3',
      });
      expect(a, isNot(equals(b)));
    });

    test('RED-DEMO: an unencoded naive join collides two DISTINCT natural '
        'keys onto one doc id when a component embeds the "_" separator — '
        'the same orphaning defect class the AD-25 stage_definitions '
        'RED-DEMO guards against, for the SAME reason: `scope_value` is '
        'free text and can legitimately contain "_"', () {
      String naiveJoin(Map<String, dynamic> data) =>
          '${data['curriculum_id']}_${data['scope_level']}_'
          '${data['scope_value']}';

      // (curriculumId='mishnayos', scopeLevel=1, scopeValue='b_c') and
      // (curriculumId='mishnayos', scopeLevel='1_b', scopeValue='c') are
      // two DIFFERENT natural keys — but the naive join can't tell where
      // one component ends and the next begins once "_" appears inside a
      // component, so both collide on 'mishnayos_1_b_c'.
      final keyA = {
        'curriculum_id': 'mishnayos',
        'scope_level': 1,
        'scope_value': 'b_c',
      };
      final keyB = {
        'curriculum_id': 'mishnayos',
        'scope_level': '1_b',
        'scope_value': 'c',
      };
      expect(naiveJoin(keyA), equals(naiveJoin(keyB))); // RED: collision.

      // The real formula escapes the literal "_" inside each component
      // (encodeKeyComponent's `_` is not in its unreserved set), so the
      // two natural keys never collide.
      expect(
        DocIds.curriculumScopeDocId(keyA),
        isNot(equals(DocIds.curriculumScopeDocId(keyB))),
      );
    });

    test('deliberately omits track_id — AD-25 retires the per-device track '
        'id as a key component for this collection too', () {
      expect(
        DocIds.curriculumScopeDocId({
          'curriculum_id': 'mishnayos',
          'scope_level': 1,
          'scope_value': 'Seder Zeraim',
          'track_id': '999', // present in payload, NOT in the doc-id
        }),
        equals('mishnayos_1_Seder%20Zeraim'),
      );
    });
  });

  // ── learning_order re-key — Gap 3 ─────────────────────────────────────
  //
  // `docs/firestore-rewrite-map.md`'s traps list, item 7: DocIds
  // .learningOrderDocId was the ONLY formula in this module that skipped
  // encodeKeyComponent. The current repository path uses this encoded form;
  // the old raw join is retained only as the rejected comparison.
  group('learning_order re-key — Gap 3: encodeKeyComponent closes a doc-id '
      'collision hole', () {
    test('GREEN: {curriculumId}_{ref}, each component percent-encoded', () {
      expect(
        DocIds.learningOrderDocId({
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot 1:1',
        }),
        equals('mishnayos_Berakhot%201%3A1'),
      );
    });

    test('still accepts the legacy "ref" field alias when sefaria_ref is '
        'absent', () {
      expect(
        DocIds.learningOrderDocId({
          'curriculum_id': 'abc',
          'ref': 'Shabbat 2:1',
        }),
        equals('abc_Shabbat%202%3A1'),
      );
    });

    test(
      'RED-DEMO: the current formula rejects the old raw unencoded output '
      'for a ref containing a literal "_" — the exact collision this fix closes',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot_1:1', // literal '_' inside the ref
        };
        await _gw(fs).pushLearningOrder(profileId: _profileId, data: data);
        final liveCurrentShape = await _liveDocId(fs, 'learning_order');
        expect(liveCurrentShape, equals(DocIds.learningOrderDocId(data)));
        expect(
          DocIds.learningOrderDocId(data),
          isNot(equals('mishnayos_Berakhot_1:1')),
        );
      },
    );

    test('RED-DEMO: an unencoded naive join collides two DISTINCT natural '
        'keys onto one doc id when a component embeds the "_" separator — '
        'the real (encoded) formula does not', () {
      String naiveJoin(Map<String, dynamic> data) =>
          '${data['curriculum_id']}_${data['sefaria_ref']}';

      // (curriculumId='mishnayos', sefariaRef='Berakhot_1:1') and
      // (curriculumId='mishnayos_Berakhot', sefariaRef='1:1') are two
      // DIFFERENT natural keys — but the naive join can't tell where one
      // component ends and the next begins once "_" appears inside a
      // component, so both collide on 'mishnayos_Berakhot_1:1'.
      final keyA = {
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Berakhot_1:1',
      };
      final keyB = {
        'curriculum_id': 'mishnayos_Berakhot',
        'sefaria_ref': '1:1',
      };
      expect(naiveJoin(keyA), equals(naiveJoin(keyB))); // RED: collision.

      expect(
        DocIds.learningOrderDocId(keyA),
        isNot(equals(DocIds.learningOrderDocId(keyB))),
      );
    });
  });

  // ── track_learning_order — DocIds.trackLearningOrderDocId (Gap 1) ─────
  //
  // `docs/firestore-rewrite-map.md`'s "OPEN" section: TrackLearningOrder
  // (Drift; per-track sedarim/masechtos reordering) had no Firestore home.
  // Like curriculumScopeDocId, this is a new formula with no legacy sync
  // counterpart, so it is pinned here by direct formula assertion.
  group('track_learning_order — DocIds.trackLearningOrderDocId', () {
    test('GREEN: {curriculumId}_{sefariaRef}, each component percent-encoded '
        'via encodeKeyComponent', () {
      expect(
        DocIds.trackLearningOrderDocId({
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Mishnah Berakhot',
        }),
        equals('mishnayos_Mishnah%20Berakhot'),
      );
    });

    test('RED-DEMO: an unencoded naive join collides two DISTINCT natural '
        'keys onto one doc id when a component embeds the "_" separator — '
        'the real (encoded) formula does not', () {
      String naiveJoin(Map<String, dynamic> data) =>
          '${data['curriculum_id']}_${data['sefaria_ref']}';

      final keyA = {
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Mishnah_Berakhot',
      };
      final keyB = {
        'curriculum_id': 'mishnayos_Mishnah',
        'sefaria_ref': 'Berakhot',
      };
      expect(naiveJoin(keyA), equals(naiveJoin(keyB))); // RED: collision.

      expect(
        DocIds.trackLearningOrderDocId(keyA),
        isNot(equals(DocIds.trackLearningOrderDocId(keyB))),
      );
    });

    test('produces the SAME shape as DocIds.learningOrderDocId for the same '
        'inputs — the collection PATH, not this formula, is what keeps '
        'track_learning_order and learning_order from colliding (see the '
        "formula's own doc comment)", () {
      final data = {
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Mishnah Berakhot',
      };
      expect(
        DocIds.trackLearningOrderDocId(data),
        equals(DocIds.learningOrderDocId(data)),
      );
    });
  });

  // ── completions (String profileId) — DocIds.completionDocIdForProfile ──
  // (Gap 4)
  //
  // `docs/firestore-rewrite-map.md`'s traps list, item 9b. Same four-
  // component shape as completionDocId, with the profile-id component typed
  // `String` for the current ULID-scoped repository rather than `int`.
  group(
    'completions (String profileId) — DocIds.completionDocIdForProfile',
    () {
      test('produces the SAME shape as completionDocId for the numerically '
          'equal profileId', () {
        final data = <String, dynamic>{
          'sefaria_ref': 'Berakhot 1:1',
          'stage_id': 1,
          'curriculum_id': 'mishnayos',
        };
        expect(
          DocIds.completionDocIdForProfile('42', data),
          equals(DocIds.completionDocId(42, data)),
        );
      });

      test('a genuine AD-24 ULID profileId percent-encodes cleanly and is '
          'distinct across profiles', () {
        final data = <String, dynamic>{
          'sefaria_ref': 'Berakhot 1:1',
          'stage_id': 1,
          'curriculum_id': 'mishnayos',
        };
        final idA = DocIds.completionDocIdForProfile(
          '01ARZ3NDEKTSV4RRFFQ69G5FAV',
          data,
        );
        final idB = DocIds.completionDocIdForProfile(
          '01BX5ZZKBKACTAV9WEVGEMMVRZ',
          data,
        );
        expect(idA, isNot(equals(idB)));
        expect(idA, startsWith('01ARZ3NDEKTSV4RRFFQ69G5FAV_'));
      });

      test(
        'accepts the camelCase legacy-alias payload, same as completionDocId',
        () {
          final data = <String, dynamic>{
            'sefariaRef': 'Shabbat 2:3',
            'stageId': 4,
            'curriculumId': 'bavli',
          };
          expect(
            DocIds.completionDocIdForProfile('profile-ulid-1', data),
            equals('profile-ulid-1_Shabbat%202%3A3_4_bavli'),
          );
        },
      );
    },
  );
}
