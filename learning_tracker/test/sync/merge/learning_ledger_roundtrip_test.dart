/// Round-trip test: the canonical write serializer (LearningLedgerCodec.encode)
/// must produce a payload that LearningLedgerMerger accepts and persists.
///
/// This test guards the Phase B invariant for learning_ledger: if encode()
/// ever drifts from the key names LearningLedgerMerger reads (e.g. completed_at
/// → wrong key), the ledger row is silently skipped on pull and learning history
/// is lost on new-device / device-restore scenarios without any error.
///
/// MISMATCH DETECTION
/// ------------------
/// The old codec emitted an entirely different schema (sefaria_ref / entry_type /
/// points / created_at) while the merger read a completely different set of keys
/// (curriculum_id / unit_identifier / track_type / completed_at / …). This test
/// would have FAILED before the codec was rewritten to match the live schema.
///
/// Key fields verified:
///   * profile_id         — decoded via FirestoreCodec.parseInt
///   * curriculum_id      — decoded as String
///   * entry_scope        — decoded as String
///   * unit_identifier    — decoded as String
///   * unit_display_name_he/en — decoded as String (optional fallback to '')
///   * track_type         — decoded as String
///   * track_id           — decoded as nullable int
///   * completed_at       — decoded as DateTime (ISO-8601 string)
///   * completion_number  — decoded as int (fallback 1)
///   * marked_by          — decoded as int (fallback 0)
///   * is_manual          — decoded as bool (fallback false)
///   * ulid               — carried through encode; used as Firestore doc-id
///
/// The test also verifies dedup: two merges of the same payload produce one
/// row (UNIQUE composite `(profileId, ulid)` on learning_ledger).
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
import 'package:learning_tracker/core/sync/merge/learning_ledger_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = LearningLedgerCodec();

const _profileId = 1;
const _ulid = '01JBVZ0000TESTLLID00000AB';
const _curriculumId = 'bavli';
const _entryScope = 'masechta';
const _unitIdentifier = 'Berakhot';
const _unitDisplayNameHe = 'ברכות';
const _unitDisplayNameEn = 'Berakhot';
const _trackType = 'personal';
// track_id is nullable (ON DELETE SET NULL); use null in the round-trip so we
// don't need to seed a curriculum_tracks row in this FK-constrained test.
const int? _trackId = null;
final _completedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
const _completionNumber = 2;
const _markedBy = _profileId;
const _isManual = false;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('learning_ledger — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late LearningLedgerMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      merger = LearningLedgerMerger(db);

      // Seed account + profile so FK constraints on learning_ledger are met.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        final row = LearningLedgerRow(
          ulid: _ulid,
          profileId: _profileId,
          curriculumId: _curriculumId,
          entryScope: _entryScope,
          unitIdentifier: _unitIdentifier,
          unitDisplayNameHe: _unitDisplayNameHe,
          unitDisplayNameEn: _unitDisplayNameEn,
          trackType: _trackType,
          trackId: _trackId,
          completedAt: _completedAt,
          completionNumber: _completionNumber,
          markedBy: _markedBy,
          isManual: _isManual,
        );
        final payload = _codec.encode(row);

        // Verify the payload carries all expected keys.
        expect(payload['ulid'], _ulid);
        expect(payload['profile_id'], _profileId);
        expect(payload['curriculum_id'], _curriculumId);
        expect(payload['entry_scope'], _entryScope);
        expect(payload['unit_identifier'], _unitIdentifier);
        expect(payload['unit_display_name_he'], _unitDisplayNameHe);
        expect(payload['unit_display_name_en'], _unitDisplayNameEn);
        expect(payload['track_type'], _trackType);
        expect(payload['track_id'], _trackId);
        expect(payload.containsKey('completed_at'), isTrue);
        expect(payload['completion_number'], _completionNumber);
        expect(payload['marked_by'], _markedBy);
        expect(payload['is_manual'], _isManual);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final entries = await db.learningLedgerDao.getEntriesByProfile(
          _profileId,
        );

        expect(
          entries,
          hasLength(1),
          reason:
              'LearningLedgerMerger must INSERT the row when codec.encode() '
              'payload is fed in — if empty, the merge read-keys diverge from '
              'the codec write-keys (push↔merge key-contract bug). '
              'Most likely cause: merger reads a key (e.g. "completed_at") '
              'that the old codec emitted under a different name '
              '("created_at"), causing the null-guard to discard the row.',
        );

        final stored = entries.first;
        expect(stored.ulid, _ulid);
        expect(stored.curriculumId, _curriculumId);
        expect(stored.unitIdentifier, _unitIdentifier);
        expect(stored.trackType, _trackType);
        expect(stored.trackId, _trackId);
        expect(stored.completionNumber, _completionNumber);
        expect(stored.markedBy, _markedBy);
        expect(stored.isManual, _isManual);

        // completed_at round-trips as UTC ISO-8601.
        final storedUtc = stored.completedAt.toUtc();
        expect(storedUtc.year, _completedAt.year);
        expect(storedUtc.month, _completedAt.month);
        expect(storedUtc.day, _completedAt.day);
      },
    );

    test(
      'dedup: two merges of the same codec payload produce exactly one DB row',
      () async {
        final payload = _codec.encode(
          LearningLedgerRow(
            ulid: _ulid,
            profileId: _profileId,
            curriculumId: _curriculumId,
            entryScope: _entryScope,
            unitIdentifier: _unitIdentifier,
            unitDisplayNameHe: _unitDisplayNameHe,
            unitDisplayNameEn: _unitDisplayNameEn,
            trackType: _trackType,
            completedAt: _completedAt,
            completionNumber: _completionNumber,
            markedBy: _markedBy,
            isManual: _isManual,
          ),
        );

        // Simulate an outbox retry: merge the same payload twice.
        await merger.merge(profileId: _profileId, rows: [payload]);
        await merger.merge(profileId: _profileId, rows: [payload]);

        final entries = await db.learningLedgerDao.getEntriesByProfile(
          _profileId,
        );
        expect(
          entries,
          hasLength(1),
          reason:
              'learning_ledger has a UNIQUE (profileId, ulid) index; '
              'a duplicate push must be silently collapsed to one row '
              '(INSERT OR IGNORE semantics).',
        );
      },
    );

    test('codec round-trips through encode → decode', () {
      final row = LearningLedgerRow(
        ulid: _ulid,
        profileId: _profileId,
        curriculumId: _curriculumId,
        entryScope: _entryScope,
        unitIdentifier: _unitIdentifier,
        unitDisplayNameHe: _unitDisplayNameHe,
        unitDisplayNameEn: _unitDisplayNameEn,
        trackType: _trackType,
        trackId: _trackId,
        completedAt: _completedAt,
        completionNumber: _completionNumber,
        markedBy: _markedBy,
        isManual: _isManual,
      );
      final payload = _codec.encode(row);
      final decoded = _codec.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.ulid, _ulid);
      expect(decoded.profileId, _profileId);
      expect(decoded.curriculumId, _curriculumId);
      expect(decoded.entryScope, _entryScope);
      expect(decoded.unitIdentifier, _unitIdentifier);
      expect(decoded.unitDisplayNameHe, _unitDisplayNameHe);
      expect(decoded.unitDisplayNameEn, _unitDisplayNameEn);
      expect(decoded.trackType, _trackType);
      expect(decoded.trackId, _trackId);
      expect(decoded.completionNumber, _completionNumber);
      expect(decoded.markedBy, _markedBy);
      expect(decoded.isManual, _isManual);

      final decodedUtc = decoded.completedAt.toUtc();
      expect(decodedUtc.year, _completedAt.year);
      expect(decodedUtc.month, _completedAt.month);
      expect(decodedUtc.day, _completedAt.day);
    });

    test('completed_at survives encode() when completedAt is non-UTC-flagged '
        '(AUD-core-sync-11: simulates the Drift round-trip, where '
        'dateTime() columns decode via DateTime.fromMillisecondsSinceEpoch '
        'with no isUtc:true, producing a local-flagged DateTime that still '
        'represents the correct instant)', () {
      // The real UTC instant the entry was completed at.
      final utcInstant = DateTime.utc(2026, 6, 18, 10, 0, 0);

      // Simulate what Drift's dateTime() column getter hands back: the
      // same instant, but flagged as local (isUtc: false) rather than
      // UTC — exactly what
      // DateTime.fromMillisecondsSinceEpoch(ms) (no isUtc:true) produces.
      final driftDecodedCompletedAt = DateTime.fromMillisecondsSinceEpoch(
        utcInstant.millisecondsSinceEpoch,
      );
      expect(
        driftDecodedCompletedAt.isUtc,
        isFalse,
        reason:
            'test setup must simulate the non-UTC-flagged value Drift '
            'actually returns; if this ever becomes true the simulation '
            'no longer matches the bug this test guards against.',
      );

      final row = LearningLedgerRow(
        ulid: _ulid,
        profileId: _profileId,
        curriculumId: _curriculumId,
        entryScope: _entryScope,
        unitIdentifier: _unitIdentifier,
        unitDisplayNameHe: _unitDisplayNameHe,
        unitDisplayNameEn: _unitDisplayNameEn,
        trackType: _trackType,
        trackId: _trackId,
        completedAt: driftDecodedCompletedAt,
        completionNumber: _completionNumber,
        markedBy: _markedBy,
        isManual: _isManual,
      );

      final payload = _codec.encode(row);
      final wireValue = payload['completed_at'] as String;

      expect(
        wireValue,
        endsWith('Z'),
        reason:
            'completed_at must always be pushed via '
            'FirestoreCodec.encodeDateTime (which forces .toUtc() before '
            'serializing) like every sibling DateTime field in this '
            'codec and every other codec in the batch. A raw '
            '.toIso8601String() on a non-UTC-flagged DateTime omits the '
            "'Z'/offset entirely, so a reading device on a different "
            'timezone reinterprets the naive string using its OWN local '
            'offset — silently shifting completedAt onto the wrong '
            'calendar day.',
      );

      // The wire value must decode back to the exact same instant,
      // independent of whichever local offset this test machine runs
      // under.
      expect(DateTime.parse(wireValue).toUtc(), utcInstant);

      // decode(encode(x)) round-trips to the correct UTC instant too —
      // this is the timezone-independence guarantee for the full codec
      // pipeline, not just the raw wire string.
      final decoded = _codec.decode(payload);
      expect(decoded, isNotNull);
      expect(decoded!.completedAt.toUtc(), utcInstant);
    });

    test('null-guard: missing curriculum_id causes decode to return null', () {
      final payload = _codec.encode(
        LearningLedgerRow(
          ulid: _ulid,
          profileId: _profileId,
          curriculumId: _curriculumId,
          entryScope: _entryScope,
          unitIdentifier: _unitIdentifier,
          unitDisplayNameHe: _unitDisplayNameHe,
          unitDisplayNameEn: _unitDisplayNameEn,
          trackType: _trackType,
          completedAt: _completedAt,
          completionNumber: _completionNumber,
          markedBy: _markedBy,
          isManual: _isManual,
        ),
      );
      // Remove required field to simulate a corrupt / partial doc.
      final broken = Map<String, dynamic>.from(payload)
        ..remove('curriculum_id');

      expect(_codec.decode(broken), isNull);
    });
  });
}
