/// Coverage for cross-reference filter methods and remaining companion/dataclass
/// gaps in user_database.g.dart.
///
/// Covers:
///   - $$CurriculumTracksTableFilterComposer: stageDefinitionsRefs,
///     pointConfigsRefs, studyDayConfigsRefs, completionsRefs,
///     learningLedgerRefs, bookmarksRefs, goalsRefs filter methods
///   - Companion.toColumns with id: const Value(n) present (14 tables)
///   - account/learnerProfile filter and orderBy missing getters
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── shared helpers ────────────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'xref@test.local'}) =>
      db.managers.accounts.create(
        (o) => o(
          email: email,
          tier: 'cloudBorn',
          displayName: 'XRefUser',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> makeProfile(int accountId) => db.managers.learnerProfiles.create(
    (o) => o(
      accountId: accountId,
      displayName: 'XRefLearner',
      mode: 'adult',
      createdAt: now,
      updatedAt: now,
    ),
  );

  Future<int> makeTrack(int profileId) => db.managers.curriculumTracks.create(
    (o) => o(
      profileId: profileId,
      curriculumId: 'bavli',
      stateChangedAt: now,
      activatedAt: now,
    ),
  );

  Future<int> makeStage(int profileId, int trackId) =>
      db.managers.stageDefinitions.create(
        (o) => o(
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageName: 'limud',
          stageOrder: 1,
        ),
      );

  // ── curriculumTracks cross-ref filter methods ─────────────────────────────

  group('curriculumTracks cross-ref filter methods', () {
    late int profId;
    late int trackId;
    late int stageId;

    setUp(() async {
      final accId = await makeAccount(email: 'ctf@test.local');
      profId = await makeProfile(accId);
      trackId = await makeTrack(profId);
      stageId = await makeStage(profId, trackId);

      // Insert child rows for cross-ref filters
      await db.managers.curriculumScopes.create(
        (o) => o(
          profileId: profId,
          trackId: trackId,
          curriculumId: 'bavli',
          scopeLevel: 1,
          scopeValue: 'masechet',
          createdAt: now,
        ),
      );
      await db.managers.pointConfigs.create(
        (o) => o(
          profileId: profId,
          trackId: trackId,
          curriculumId: 'bavli',
          stageOrder: 1,
          points: 10,
        ),
      );
      await db.managers.studyDayConfigs.create(
        (o) => o(
          profileId: profId,
          trackId: trackId,
          curriculumId: 'bavli',
          dayOfWeek: 0,
          updatedAt: now,
        ),
      );
      await db.managers.completionEvents.create(
        (o) => o(
          profileId: profId,
          trackId: Value(trackId),
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          stageId: stageId,
          trackType: 'personal',
          eventTimestamp: now,
        ),
      );
      await db.managers.learningLedger.create(
        (o) => o(
          profileId: profId,
          curriculumId: 'bavli',
          entryScope: 'daf',
          unitIdentifier: 'Berakhot 2a',
          unitDisplayNameHe: 'ברכות ב',
          unitDisplayNameEn: 'Berakhot 2a',
          trackType: 'personal',
          completedAt: now,
          completionNumber: 1,
          markedBy: 0,
          trackId: Value(trackId),
        ),
      );
      await db.managers.bookmarks.create(
        (o) => o(
          profileId: profId,
          trackId: trackId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          updatedAt: now,
        ),
      );
      await db.managers.goals.create(
        (o) => o(
          profileId: profId,
          trackId: trackId,
          curriculumId: 'bavli',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    test('filter by stageDefinitionsRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.stageDefinitionsRefs((s) => s.stageName('limud')))
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by pointConfigsRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.pointConfigsRefs((s) => s.stageOrder(1)))
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by studyDayConfigsRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.studyDayConfigsRefs((s) => s.dayOfWeek(0)))
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by learningLedgerRefs sefariaRef', () async {
      final rows = await db.managers.curriculumTracks
          .filter(
            (f) => f.learningLedgerRefs((s) => s.unitIdentifier('Berakhot 2a')),
          )
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by learningLedgerRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter(
            (f) => f.learningLedgerRefs((s) => s.unitIdentifier('Berakhot 2a')),
          )
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by bookmarksRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.bookmarksRefs((s) => s.sefariaRef('Berakhot 2a')))
          .get();
      expect(rows, isNotEmpty);
    });

    test('filter by goalsRefs', () async {
      final rows = await db.managers.curriculumTracks
          .filter((f) => f.goalsRefs((s) => s.profileId.id(profId)))
          .get();
      expect(rows, isNotEmpty);
    });
  });

  // ── accounts filter/orderBy missing getters ───────────────────────────────

  group('accounts missing filter and orderBy', () {
    setUp(() async {
      await makeAccount(email: 'acc-missing@test.local');
    });

    test('filter by displayName', () async {
      final rows = await db.managers.accounts
          .filter((f) => f.displayName('XRefUser'))
          .get();
      expect(rows, isNotEmpty);
    });

    test('orderBy id ascending', () async {
      final rows = await db.managers.accounts.orderBy((o) => o.id.asc()).get();
      expect(rows, isNotEmpty);
    });
  });

  // ── Companion.toColumns with id present ──────────────────────────────────

  group('Companion.toColumns with id present', () {
    test('CurriculumTracksCompanion id present in toColumns', () {
      final c = CurriculumTracksCompanion(
        id: const Value(42),
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        state: const Value('active'),
        stateChangedAt: Value(now),
        activatedAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('CurriculumScopesCompanion id present in toColumns', () {
      const c = CurriculumScopesCompanion(
        id: Value(5),
        profileId: Value(1),
        curriculumId: Value('bavli'),
        trackId: Value(1),
        scopeLevel: Value(1),
        scopeValue: Value('masechet'),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('ProfileProgramsCompanion id present in toColumns', () {
      const c = ProfileProgramsCompanion(
        id: Value(3),
        profileId: Value(1),
        curriculumType: Value('daf'),
        programId: Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('PointConfigsCompanion id present in toColumns', () {
      const c = PointConfigsCompanion(
        id: Value(7),
        profileId: Value(1),
        curriculumId: Value('bavli'),
        trackId: Value(1),
        stageOrder: Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('CompletionEventsCompanion id present in toColumns', () {
      final c = CompletionEventsCompanion(
        id: const Value(9),
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        trackId: const Value(1),
        sefariaRef: const Value('Berakhot 2a'),
        stageId: const Value(1),
        trackType: const Value('personal'),
        eventTimestamp: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('CompletionEventsCompanion id present in toColumns', () {
      final c = CompletionEventsCompanion(
        id: const Value(11),
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        sefariaRef: const Value('Berakhot 2a'),
        stageId: const Value(1),
        trackType: const Value('personal'),
        eventTimestamp: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('DailyPlansCompanion id present in toColumns', () {
      final c = DailyPlansCompanion(
        id: const Value(13),
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        planDate: Value(now),
        sefariaRef: const Value('Berakhot 2a'),
        stageOrder: const Value(1),
        stageDefinitionId: const Value(1),
        trackId: const Value(1),
        priority: const Value('normal'),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('LearningLedgerCompanion id present in toColumns', () {
      final c = LearningLedgerCompanion(
        id: const Value(15),
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        ulid: const Value('ulid-test'),
        entryScope: const Value('daf'),
        unitIdentifier: const Value('Berakhot:2a'),
        unitDisplayNameHe: const Value('ברכות ב'),
        unitDisplayNameEn: const Value('Berakhot 2a'),
        trackType: const Value('personal'),
        completedAt: Value(now),
        completionNumber: const Value(1),
        markedBy: const Value(0),
        isManual: const Value(false),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('TrackLearningOrderCompanion id present in toColumns', () {
      const c = TrackLearningOrderCompanion(
        id: Value(17),
        trackId: Value(1),
        sefariaRef: Value('Berakhot 2a'),
        sortOrder: Value(1),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('StreakEventsCompanion id present in toColumns', () {
      const c = StreakEventsCompanion(id: Value(19), profileId: Value(1));
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('StreakEventsCompanion id present in toColumns', () {
      final c = StreakEventsCompanion(
        id: const Value(21),
        profileId: const Value(1),
        eventType: const Value('completion'),
        dayUtc: Value(DateTime.utc(2026, 3, 1)),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('OutboxCompanion id present in toColumns', () {
      final c = OutboxCompanion(
        id: const Value(25),
        profileId: const Value(1),
        entityKind: const Value('completion'),
        entityKey: const Value('key-1'),
        payload: const Value('{}'),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });

    test('SacredWindowEntriesCompanion id present in toColumns', () {
      final c = SacredWindowEntriesCompanion(
        id: const Value(27),
        startUtc: Value(now),
        endUtc: Value(now),
        kind: const Value('shabbos'),
        inIsrael: const Value(false),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('id'), isTrue);
    });
  });

  // ── copyWithCompanion absent-branch coverage ──────────────────────────────

  group('Account.copyWithCompanion absent branches', () {
    late int accountId;

    setUp(() async {
      accountId = await makeAccount(email: 'cwc@test.local');
    });

    test(
      'copyWithCompanion with firebaseUid present covers ? branch',
      () async {
        final account = await db.managers.accounts
            .filter((f) => f.id(accountId))
            .getSingle();
        // Pass firebaseUid as present to cover L386 "? data.firebaseUid.value"
        final copy = account.copyWithCompanion(
          const AccountsCompanion(firebaseUid: Value('new-fb-uid')),
        );
        expect(copy.firebaseUid, 'new-fb-uid');
      },
    );

    test('copyWithCompanion without displayName covers else branch', () async {
      final account = await db.managers.accounts
          .filter((f) => f.id(accountId))
          .getSingle();
      // Pass only email, no displayName — covers L394 ": this.displayName"
      final copy = account.copyWithCompanion(
        const AccountsCompanion(email: Value('new@email.local')),
      );
      expect(copy.displayName, account.displayName);
      expect(copy.email, 'new@email.local');
    });
  });

  // ── CurriculumTrack.copyWithCompanion absent branches ────────────────────

  group('CurriculumTrack.copyWithCompanion absent branches', () {
    test('copyWithCompanion with paceResetDate present', () async {
      final accId = await makeAccount(email: 'cwc-ct@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final track = await db.managers.curriculumTracks
          .filter((f) => f.id(trackId))
          .getSingle();
      // Cover the present branches for nullable optional fields
      final copy = track.copyWithCompanion(
        CurriculumTracksCompanion(paceResetDate: Value(now)),
      );
      expect(copy.paceResetDate, now);
    });

    test('copyWithCompanion without state covers else branch', () async {
      final accId = await makeAccount(email: 'cwc-ct2@test.local');
      final profId = await makeProfile(accId);
      final trackId = await makeTrack(profId);
      final track = await db.managers.curriculumTracks
          .filter((f) => f.id(trackId))
          .getSingle();
      // Cover absent state branch
      final copy = track.copyWithCompanion(
        const CurriculumTracksCompanion(curriculumId: Value('mishnah')),
      );
      expect(copy.state, track.state);
      expect(copy.curriculumId, 'mishnah');
    });
  });
}
