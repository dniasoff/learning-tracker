/// Story acceptance tests for Epic 25 — Schema + Core Foundation.
///
/// Story 25.5 (DNI-326): Outbox table and OutboxProcessor scaffolding.
/// Story 25.8 (DNI-329): ContentIndex + ProgramRefResolver.
/// Story 25.11 (DNI-332): AuthRepository — sole firebase_auth consumer.
@Tags(['epic_25'])
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

UserDatabase _createDb() => UserDatabase(NativeDatabase.memory());

OutboxCompanion _completionRow({
  int profileId = 1,
  String entityKey = 'comp-001',
}) => OutboxCompanion.insert(
  profileId: profileId,
  entityKind: OutboxEntityKind.completion,
  entityKey: entityKey,
  payload: jsonEncode({'ref': 'Mishnah Berakhot 1'}),
  createdAt: DateTime.utc(2026, 5, 13, 10),
);

// ── mocks ─────────────────────────────────────────────────────────────────────

class MockPushPipeline extends Mock implements PushPipeline {}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  // --------------------------------------------------------------------------
  // Story 25.5 — Outbox table and OutboxProcessor scaffolding (DNI-326)
  // --------------------------------------------------------------------------

  group(
    'Story 25.5 — Outbox table and OutboxProcessor scaffolding',
    tags: ['story_25_5'],
    () {
      // ── 1. Table existence and basic insert ────────────────────────────────

      group('outbox table', () {
        late UserDatabase db;

        setUp(() => db = _createDb());
        tearDown(() => db.close());

        test('can insert a row into the outbox table', () async {
          final id = await db.outboxDao.insertOutboxRow(_completionRow());

          expect(id, greaterThan(0));

          final rows = await db.select(db.outbox).get();
          expect(rows, hasLength(1));
          expect(rows.first.entityKind, equals(OutboxEntityKind.completion));
          expect(rows.first.profileId, equals(1));
          expect(rows.first.entityKey, equals('comp-001'));
          expect(rows.first.attempts, equals(0));
          expect(rows.first.lastError, isNull);
          expect(rows.first.lastAttemptAt, isNull);
        });

        test(
          'getPendingByKind returns rows for matching kind and profileId',
          () async {
            // Insert two completions for profile 1 and one streak for profile 1.
            await db.outboxDao.insertOutboxRow(
              _completionRow(profileId: 1, entityKey: 'comp-001'),
            );
            await db.outboxDao.insertOutboxRow(
              _completionRow(profileId: 1, entityKey: 'comp-002'),
            );
            await db.outboxDao.insertOutboxRow(
              OutboxCompanion.insert(
                profileId: 1,
                entityKind: OutboxEntityKind.streak,
                entityKey: 'streak-001',
                payload: jsonEncode({'current': 5}),
                createdAt: DateTime.utc(2026, 5, 13, 11),
              ),
            );
            // Insert a completion for a different profile (must not show up).
            await db.outboxDao.insertOutboxRow(
              _completionRow(profileId: 99, entityKey: 'comp-other'),
            );

            final completions = await db.outboxDao.getPendingByKind(
              OutboxEntityKind.completion,
              1,
            );
            expect(completions, hasLength(2));
            expect(
              completions.map((r) => r.entityKey),
              containsAll(['comp-001', 'comp-002']),
            );
          },
        );

        test('getPendingByKind respects limit parameter', () async {
          // Insert 5 rows.
          for (var i = 0; i < 5; i++) {
            await db.outboxDao.insertOutboxRow(
              _completionRow(entityKey: 'comp-00$i'),
            );
          }

          final result = await db.outboxDao.getPendingByKind(
            OutboxEntityKind.completion,
            1,
            limit: 3,
          );
          expect(result, hasLength(3));
        });

        test('markAttempted increments attempts and records error', () async {
          final id = await db.outboxDao.insertOutboxRow(_completionRow());

          await db.outboxDao.markAttempted(id, error: 'timeout');

          final rows = await db.select(db.outbox).get();
          expect(rows.first.attempts, equals(1));
          expect(rows.first.lastError, equals('timeout'));
          expect(rows.first.lastAttemptAt, isNotNull);
        });

        test('deleteRow removes the row', () async {
          final id = await db.outboxDao.insertOutboxRow(_completionRow());

          await db.outboxDao.deleteRow(id);

          final rows = await db.select(db.outbox).get();
          expect(rows, isEmpty);
        });
      });

      // ── 2. Transactional atomicity ─────────────────────────────────────────

      group('transaction atomicity', () {
        late UserDatabase db;

        setUp(() => db = _createDb());
        tearDown(() => db.close());

        test(
          'outbox insert inside transaction rolls back when transaction aborts',
          () async {
            // Simulate the outbox insert failing inside a transaction by
            // deliberately throwing after the outbox insert. The outbox row
            // must not be committed.
            await expectLater(
              () => db.transaction(() async {
                await db.outboxDao.insertOutboxRow(_completionRow());
                // Simulate a downstream failure in the same transaction.
                throw Exception('simulated write failure');
              }),
              throwsA(isA<Exception>()),
            );

            final outboxRows = await db.select(db.outbox).get();
            expect(
              outboxRows,
              isEmpty,
              reason:
                  'outbox row must be rolled back when the transaction fails',
            );
          },
        );

        test(
          'outbox insert commits together with other writes in same transaction',
          () async {
            // Insert an outbox row inside a transaction that also writes a
            // streak row. Both should commit successfully.
            await db.transaction(() async {
              await db.outboxDao.insertOutboxRow(_completionRow());
              await db
                  .into(db.streaks)
                  .insert(StreaksCompanion.insert(profileId: 1));
            });

            final outboxRows = await db.select(db.outbox).get();
            final streakRows = await db.select(db.streaks).get();
            expect(outboxRows, hasLength(1));
            expect(streakRows, hasLength(1));
          },
        );
      });

      // ── 3. OutboxProcessor drain ──────────────────────────────────────────

      group('OutboxProcessor.drain', () {
        late UserDatabase db;
        late OutboxDao dao;
        late MockPushPipeline mockPipeline;
        late OutboxProcessor processor;

        setUp(() {
          db = _createDb();
          dao = db.outboxDao;
          mockPipeline = MockPushPipeline();
          processor = OutboxProcessor(outboxDao: dao, pipeline: mockPipeline);

          // Default: all push methods succeed.
          when(
            () => mockPipeline.pushCompletion(
              profileId: any(named: 'profileId'),
              entityKey: any(named: 'entityKey'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) async {});
        });

        tearDown(() => db.close());

        test('drain deletes rows that push successfully', () async {
          await dao.insertOutboxRow(_completionRow());

          final pushed = await processor.drain(1);

          expect(pushed, equals(1));
          final remaining = await db.select(db.outbox).get();
          expect(remaining, isEmpty);
        });

        test('drain calls pushCompletion with correct arguments', () async {
          await dao.insertOutboxRow(_completionRow(entityKey: 'comp-abc'));

          await processor.drain(1);

          verify(
            () => mockPipeline.pushCompletion(
              profileId: 1,
              entityKey: 'comp-abc',
              payload: {'ref': 'Mishnah Berakhot 1'},
            ),
          ).called(1);
        });

        test('drain marks row with error when push fails', () async {
          when(
            () => mockPipeline.pushCompletion(
              profileId: any(named: 'profileId'),
              entityKey: any(named: 'entityKey'),
              payload: any(named: 'payload'),
            ),
          ).thenThrow(Exception('network error'));

          final id = await dao.insertOutboxRow(_completionRow());

          final pushed = await processor.drain(1);

          expect(pushed, equals(0));
          final rows = await db.select(db.outbox).get();
          expect(rows, hasLength(1));
          expect(rows.first.id, equals(id));
          expect(rows.first.attempts, equals(1));
          expect(rows.first.lastError, contains('network error'));
        });

        test(
          'drain accumulates 50 rows offline and clears them all on reconnect',
          () async {
            // Insert 50 completion rows — simulating offline accumulation.
            for (var i = 0; i < 50; i++) {
              await dao.insertOutboxRow(_completionRow(entityKey: 'comp-$i'));
            }

            final pendingBefore = await dao.getPendingByKind(
              OutboxEntityKind.completion,
              1,
              limit: 100,
            );
            expect(pendingBefore, hasLength(50));

            // Drain (device "reconnects") — all 50 should push and be deleted.
            final pushed = await processor.drain(1);

            expect(pushed, equals(50));
            final remaining = await db.select(db.outbox).get();
            expect(remaining, isEmpty);

            verify(
              () => mockPipeline.pushCompletion(
                profileId: 1,
                entityKey: any(named: 'entityKey'),
                payload: any(named: 'payload'),
              ),
            ).called(50);
          },
        );

        test(
          'drain respects batch size of 50 — leaves excess rows untouched',
          () async {
            // Insert 60 rows; only 50 should be processed per drain call.
            for (var i = 0; i < 60; i++) {
              await dao.insertOutboxRow(_completionRow(entityKey: 'comp-$i'));
            }

            final pushed = await processor.drain(1);

            expect(pushed, equals(50));
            final remaining = await db.select(db.outbox).get();
            expect(remaining, hasLength(10));
          },
        );

        test('drain does not process rows for other profiles', () async {
          // Insert rows for profile 1 and profile 2.
          await dao.insertOutboxRow(_completionRow(profileId: 1));
          await dao.insertOutboxRow(_completionRow(profileId: 2));

          // Drain only for profile 1.
          final pushed = await processor.drain(1);

          expect(pushed, equals(1));
          // Profile 2's row must still be present.
          final remaining = await db.select(db.outbox).get();
          expect(remaining, hasLength(1));
          expect(remaining.first.profileId, equals(2));
        });
      });
    },
  );

  // --------------------------------------------------------------------------
  // Story 25.11 — AuthRepository sole firebase_auth consumer (DNI-332)
  // --------------------------------------------------------------------------

  group(
    'Story 25.11 — AuthRepository sole firebase_auth consumer',
    tags: ['story_25_11'],
    () {
      // ── 1. AuthRepository interface exposes required members ───────────────

      test(
        'AuthRepository interface declares currentUser, onAuthStateChanged, signIn, signInWithGoogle, signOut',
        () {
          // Verify the abstract class has the expected members by constructing
          // a mock and calling them. This is a compile-time check — if the
          // interface is missing a member, the mock class cannot compile.
          final repo = _MockAuthRepository();

          when(() => repo.currentUser).thenReturn(null);
          when(
            () => repo.onAuthStateChanged(),
          ).thenAnswer((_) => Stream.value(null));
          when(
            () => repo.signInWithEmail(any(), any()),
          ).thenAnswer((_) async {});
          when(() => repo.signInWithGoogle()).thenAnswer((_) async {});
          when(() => repo.signOut()).thenAnswer((_) async {});

          expect(repo.currentUser, isNull);
          expect(repo.onAuthStateChanged(), isA<Stream<AppUser?>>());

          // Verify the calls complete without error.
          expect(
            () async => repo.signInWithEmail('a@b.com', 'pw'),
            returnsNormally,
          );
          expect(() async => repo.signInWithGoogle(), returnsNormally);
          expect(() async => repo.signOut(), returnsNormally);
        },
      );

      // ── 2. AppUser maps uid, email, displayName, emailVerified, providers ─

      test('AppUser holds all required fields', () {
        const user = AppUser(
          uid: 'uid-123',
          email: 'test@example.com',
          displayName: 'Test User',
          emailVerified: true,
          providers: ['password', 'google.com'],
        );

        expect(user.uid, equals('uid-123'));
        expect(user.email, equals('test@example.com'));
        expect(user.displayName, equals('Test User'));
        expect(user.emailVerified, isTrue);
        expect(user.providers, containsAll(['password', 'google.com']));
      });

      test('AppUser allows null email and displayName', () {
        const user = AppUser(
          uid: 'uid-456',
          email: null,
          displayName: null,
          emailVerified: false,
          providers: [],
        );

        expect(user.uid, equals('uid-456'));
        expect(user.email, isNull);
        expect(user.displayName, isNull);
        expect(user.emailVerified, isFalse);
        expect(user.providers, isEmpty);
      });

      // ── 3. onAuthStateChanged emits AppUser? not firebase User? ───────────

      test('onAuthStateChanged stream emits AppUser? typed values', () async {
        final repo = _MockAuthRepository();
        const mockUser = AppUser(
          uid: 'uid-789',
          email: 'mock@test.com',
          displayName: 'Mock',
          emailVerified: true,
          providers: ['password'],
        );

        when(
          () => repo.onAuthStateChanged(),
        ).thenAnswer((_) => Stream.fromIterable([mockUser, null]));

        final emitted = await repo.onAuthStateChanged().toList();
        expect(emitted, hasLength(2));
        expect(emitted[0], isA<AppUser>());
        expect((emitted[0] as AppUser).uid, equals('uid-789'));
        expect(emitted[1], isNull);
      });

      // ── 4. AppUser.providers replaces providerData ─────────────────────────

      test('providers list supports contains() for password provider', () {
        const user = AppUser(
          uid: 'uid-pw',
          email: 'pw@test.com',
          displayName: null,
          emailVerified: true,
          providers: ['password'],
        );

        expect(user.providers.contains('password'), isTrue);
        expect(user.providers.contains('google.com'), isFalse);
      });

      test('providers list supports contains() for google.com provider', () {
        const user = AppUser(
          uid: 'uid-google',
          email: 'g@test.com',
          displayName: 'Google User',
          emailVerified: true,
          providers: ['google.com'],
        );

        expect(user.providers.contains('google.com'), isTrue);
        expect(user.providers.contains('password'), isFalse);
      });
    },
  );

  // --------------------------------------------------------------------------
  // Story 25.8 — ContentIndex + ProgramRefResolver (DNI-329)
  // --------------------------------------------------------------------------

  group('Story 25.8 — ContentIndex + ProgramRefResolver', tags: ['story_25_8'], () {
    // ── ContentIndex ──────────────────────────────────────────────────────

    group('ContentIndex', () {
      test('lookup returns the item for a known sefariaRef', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final result = index.lookup('Mishnah Berakhot 1:1');

        expect(result, isNotNull);
        expect(result!.curriculumId, equals('mishnayos'));
        expect(result.displayNameEn, equals('Mishnah 1'));
      });

      test('lookup returns null for an unknown sefariaRef', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        expect(index.lookup('Made-up Ref 99:99'), isNull);
      });

      test('lookup spans all curricula (cross-curriculum match)', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final bavli = index.lookup('Berakhot 2a');
        final mishnah = index.lookup('Mishnah Berakhot 1:1');

        expect(bavli?.curriculumId, equals('bavli'));
        expect(mishnah?.curriculumId, equals('mishnayos'));
      });

      test('size reports total indexed items', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        // 4 mishnayos + 3 bavli leaves + 2 mishnayos containers = 9
        expect(index.size, equals(9));
      });

      test('adjacent returns prev/next leaves within same curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:2');

        expect(adj.prev, isNotNull);
        expect(adj.prev!.sefariaRef, equals('Mishnah Berakhot 1:1'));
        expect(adj.next, isNotNull);
        expect(adj.next!.sefariaRef, equals('Mishnah Berakhot 1:3'));
      });

      test('adjacent returns null prev at first leaf of curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:1');

        expect(adj.prev, isNull);
        expect(adj.next, isNotNull);
      });

      test('adjacent returns null next at last leaf of curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:4');

        expect(adj.prev, isNotNull);
        expect(adj.next, isNull);
      });

      test('adjacent returns (null, null) for unknown ref', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Made-up Ref 99:99');

        expect(adj.prev, isNull);
        expect(adj.next, isNull);
      });

      test('adjacent does NOT cross curriculum boundaries', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        // Last leaf of mishnayos in this fixture is Berakhot 1:4;
        // adjacent.next must be null even though bavli items exist
        // elsewhere in the index.
        final adj = index.adjacent('Mishnah Berakhot 1:4');

        expect(adj.next, isNull);
      });

      test('lookup completes in < 1ms after first warmup (NFR22 benchmark)', () {
        // Build a large index to make any O(N) walk visible.
        final items = <CurriculumId, List<ContentItem>>{};
        for (final c in CurriculumId.values) {
          items[c] = _generateLeafItems(c, count: 6000);
        }
        final index = ContentIndex.fromCurricula(items);

        // Warmup — exercise the cache once.
        index.lookup(items[CurriculumId.bavli]!.first.sefariaRef);

        const iterations = 10000;
        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          final c = CurriculumId.values[i % CurriculumId.values.length];
          final ref = items[c]![i % items[c]!.length].sefariaRef;
          index.lookup(ref);
        }
        stopwatch.stop();

        final perLookupUs = stopwatch.elapsedMicroseconds / iterations;

        expect(
          perLookupUs,
          lessThan(1000),
          reason:
              'lookup must complete in < 1ms (=1000us) per call after warmup; '
              'measured ${perLookupUs.toStringAsFixed(2)}us',
        );
      });
    });

    // ── ProgramRefResolver ────────────────────────────────────────────────

    group('ProgramRefResolver', () {
      test('resolve returns the canonical sefariaRef for the program day', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            ('daf_yomi', 0): 'Berakhot 2a',
          }),
        );

        final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 0);

        expect(ref, equals('Berakhot 2a'));
      });

      test('resolve normalizes whitespace and case variants to canonical', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            // Calendar feed sometimes returns spacing/case variants
            // ("mishna" → "mishnah"). Resolver must normalize to the
            // canonical content-index ref.
            ('mishna_yomit', 0): 'Mishna  Berakhot 1:1',
          }),
        );

        final ref = resolver.resolve(programId: 'mishna_yomit', dayOffset: 0);

        expect(ref, equals('Mishnah Berakhot 1:1'));
      });

      test(
        'resolve returns null when the program has no entry for the day',
        () {
          final index = ContentIndex.fromCurricula(_smallCurriculumSet());
          final resolver = ProgramRefResolver(
            index: index,
            programRefSource: _StubProgramRefSource(const {}),
          );

          final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 5);

          expect(ref, isNull);
        },
      );

      test(
        'resolve returns null when calendar ref does not match any ContentIndex entry',
        () {
          final index = ContentIndex.fromCurricula(_smallCurriculumSet());
          final resolver = ProgramRefResolver(
            index: index,
            programRefSource: _StubProgramRefSource({
              ('daf_yomi', 0): 'Hullin 7', // not in this fixture's index
            }),
          );

          final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 0);

          // Resolver MUST NOT fall back to the raw display string —
          // T1.7 explicitly forbids that. Return null instead.
          expect(ref, isNull);
        },
      );

      test('different dayOffsets map to different refs', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            ('daf_yomi', 0): 'Berakhot 2a',
            ('daf_yomi', 1): 'Berakhot 2b',
            ('daf_yomi', 2): 'Berakhot 3a',
          }),
        );

        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 0),
          equals('Berakhot 2a'),
        );
        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 1),
          equals('Berakhot 2b'),
        );
        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 2),
          equals('Berakhot 3a'),
        );
      });
    });
  });
}

// ── Story 25.8 helpers ───────────────────────────────────────────────────────

/// Builds a small but realistic content fixture spanning two curricula:
/// 1 masechta of Mishnah Berakhot with 4 mishnayos (plus 2 containers),
/// and 3 leaf amudim of Bavli Berakhot.
Map<CurriculumId, List<ContentItem>> _smallCurriculumSet() {
  final mishnayos = <ContentItem>[
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      displayNameHe: 'זרעים',
      displayNameEn: 'Zeraim',
      sefariaRef: 'Zeraim',
      sortOrder: 0,
      isLeaf: false,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'ברכות',
      displayNameEn: 'Berakhot',
      sefariaRef: 'Mishnah Berakhot',
      sortOrder: 1,
      isLeaf: false,
    ),
    for (var i = 1; i <= 4; i++)
      ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: 'Perek 1',
        level4: 'Mishnah $i',
        displayNameHe: 'משנה $i',
        displayNameEn: 'Mishnah $i',
        sefariaRef: 'Mishnah Berakhot 1:$i',
        sortOrder: 1 + i,
        isLeaf: true,
      ),
  ];

  final bavli = <ContentItem>[
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 2',
      level3: 'Amud a',
      displayNameHe: 'ברכות ב.',
      displayNameEn: 'Berakhot 2a',
      sefariaRef: 'Berakhot 2a',
      sortOrder: 0,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 2',
      level3: 'Amud b',
      displayNameHe: 'ברכות ב:',
      displayNameEn: 'Berakhot 2b',
      sefariaRef: 'Berakhot 2b',
      sortOrder: 1,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 3',
      level3: 'Amud a',
      displayNameHe: 'ברכות ג.',
      displayNameEn: 'Berakhot 3a',
      sefariaRef: 'Berakhot 3a',
      sortOrder: 2,
      isLeaf: true,
    ),
  ];

  return {CurriculumId.mishnayos: mishnayos, CurriculumId.bavli: bavli};
}

/// Synthesises [count] unique leaf items for [curriculum]. Used by the
/// benchmark test to size the index up to realistic content scale
/// (~52K rows across 9 curricula).
List<ContentItem> _generateLeafItems(
  CurriculumId curriculum, {
  required int count,
}) {
  final prefix = curriculum.storageKey;
  return [
    for (var i = 0; i < count; i++)
      ContentItem(
        curriculumId: curriculum.storageKey,
        level1: 'Section',
        level2: 'Unit $i',
        displayNameHe: '$prefix-$i',
        displayNameEn: '$prefix-$i',
        sefariaRef: '$prefix-bench:$i',
        sortOrder: i,
        isLeaf: true,
      ),
  ];
}

/// Stub implementation of [ProgramRefSource] for tests. Backs a fixed
/// `(programId, dayOffset) → rawRef` map; returns null otherwise.
class _StubProgramRefSource implements ProgramRefSource {
  _StubProgramRefSource(this._map);

  final Map<(String, int), String> _map;

  @override
  String? rawRefFor({required String programId, required int dayOffset}) =>
      _map[(programId, dayOffset)];
}

// ── mock for story 25.11 ──────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}
