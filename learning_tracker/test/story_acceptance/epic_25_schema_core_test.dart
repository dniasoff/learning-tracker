/// Story acceptance tests for Epic 25 — Schema + Core Foundation.
///
/// Story 25.3 (DNI-324): Composite indexes on hot-path queries.
/// Story 25.5 (DNI-326): Outbox table and OutboxProcessor scaffolding.
/// Story 25.7 (DNI-328): core/preferences/ ProfileScopedPreference primitives.
/// Story 25.8 (DNI-329): ContentIndex + ProgramRefResolver.
/// Story 25.10 (DNI-331): LocalDayClock — single time provider.
/// Story 25.11 (DNI-332): AuthRepository — sole firebase_auth consumer.
/// Story 25.19 (DNI-340): core/logging/ — finalize structured AppLogger and
///                        migrate remaining production logs.
@Tags(['epic_25'])
// The Story 25.17 deletion-proof test uses `dynamic` dispatch to confirm
// the public CompletionDao methods are gone — that's the whole point of
// the test, so suppress the analyzer warning at file scope.
// ignore_for_file: avoid_dynamic_calls
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/track_scope.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/app_locale_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/nikud_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/preferences/transliteration_variant_preference.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedCompletion, seedProfile;

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
  // Story 25.3 — Composite indexes on hot-path queries (DNI-324)
  // --------------------------------------------------------------------------

  group(
    'Story 25.3 — Composite indexes on hot-path queries',
    tags: ['story_25_3'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = _createDb();
        await seedProfile(db);
      });
      tearDown(() => db.close());

      // ── Helpers ──────────────────────────────────────────────────────────

      Future<List<String>> indexNamesForTable(String tableName) async {
        final rows = await db
            .customSelect(
              'SELECT name FROM sqlite_master '
              "WHERE type = 'index' AND tbl_name = ? "
              'ORDER BY name',
              variables: [Variable.withString(tableName)],
            )
            .get();
        return rows.map((r) => r.read<String>('name')).toList();
      }

      Future<List<Map<String, Object?>>> explain(
        String sql, {
        List<Variable> variables = const [],
      }) async {
        final rows = await db
            .customSelect('EXPLAIN QUERY PLAN $sql', variables: variables)
            .get();
        return rows.map((r) => r.data).toList();
      }

      bool planUsesIndex(List<Map<String, Object?>> plan, String table) {
        return plan.any((row) {
          final detail = (row['detail'] as String?) ?? '';
          return detail.contains('SEARCH') &&
              detail.contains(table) &&
              detail.contains('USING') &&
              detail.contains('INDEX');
        });
      }

      // ── 1. Index existence ───────────────────────────────────────────────

      test('completions has composite index '
          'completions_pidx_pid_cur_completed on '
          '(profileId, curriculumId, completedAt DESC)', () async {
        final indexes = await indexNamesForTable('completions');
        expect(
          indexes,
          contains('completions_pidx_pid_cur_completed'),
          reason: 'AR4 hot-path composite index missing on completions',
        );

        final master = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type = 'index' "
              "AND name = 'completions_pidx_pid_cur_completed'",
            )
            .getSingleOrNull();
        final sql = (master?.read<String?>('sql') ?? '').toLowerCase();
        expect(
          sql,
          contains('profile_id'),
          reason: 'Index must include profileId',
        );
        expect(
          sql,
          contains('curriculum_id'),
          reason: 'Index must include curriculumId',
        );
        expect(
          sql,
          contains('completed_at'),
          reason: 'Index must include completedAt',
        );
        expect(
          sql,
          contains('desc'),
          reason: 'completedAt column must be ordered DESC for AR4',
        );
      });

      test(
        'completions has composite index on '
        '(profileId, sefariaRef, stageId, trackType) — natural-key lookups',
        () async {
          // Note: the UNIQUE part of Story 25.2 lives on the new
          // `completion_events` table introduced by DNI-323. DNI-324 keeps
          // this composite NON-UNIQUE on the existing `completions`
          // history table so review-count semantics (multiple completions
          // of the same natural key) continue to work.
          final indexes = await indexNamesForTable('completions');
          final natKey = indexes.firstWhere(
            (n) => n.contains('completions') && n.contains('natural'),
            orElse: () => '',
          );
          expect(
            natKey,
            isNotEmpty,
            reason:
                'Expected a composite index covering '
                '(profileId, sefariaRef, stageId, trackType)',
          );

          final master = await db
              .customSelect(
                'SELECT sql FROM sqlite_master '
                "WHERE type = 'index' AND name = ?",
                variables: [Variable.withString(natKey)],
              )
              .getSingleOrNull();
          final sql = (master?.read<String?>('sql') ?? '').toLowerCase();
          expect(sql, contains('profile_id'));
          expect(sql, contains('sefaria_ref'));
          expect(sql, contains('stage_id'));
          expect(sql, contains('track_type'));
        },
      );

      test(
        'learning_ledger has composite index on (profileId, createdAt)',
        () async {
          final indexes = await indexNamesForTable('learning_ledger');
          final ledgerHotPath = indexes.firstWhere(
            (n) => n.startsWith('learning_ledger') && n.contains('created'),
            orElse: () => '',
          );
          expect(
            ledgerHotPath,
            isNotEmpty,
            reason:
                'AR4 hot-path index missing on learning_ledger(profileId, createdAt)',
          );

          final master = await db
              .customSelect(
                'SELECT sql FROM sqlite_master '
                "WHERE type = 'index' AND name = ?",
                variables: [Variable.withString(ledgerHotPath)],
              )
              .getSingleOrNull();
          final sql = (master?.read<String?>('sql') ?? '').toLowerCase();
          expect(sql, contains('profile_id'));
          expect(sql, contains('created_at'));
        },
      );

      test(
        'streak_events has UNIQUE composite index on natural-key columns',
        () async {
          // DNI-323 (parallel) renames the day column to dayUtc; today the
          // table exposes (profileId, eventTimestamp, eventType) declared
          // via Drift's `uniqueKeys`, which produces an auto-index
          // (sqlite_autoindex_streak_events_*). Either shape satisfies AR4
          // as long as a UNIQUE composite index is present.
          final pragmaRows = await db
              .customSelect(
                'SELECT name, "unique" AS u FROM pragma_index_list(?)',
                variables: [Variable.withString('streak_events')],
              )
              .get();
          final uniqueIndexes = pragmaRows
              .where((r) => r.read<int>('u') == 1)
              .map((r) => r.read<String>('name'))
              .toList();
          expect(
            uniqueIndexes,
            isNotEmpty,
            reason:
                'AR4 UNIQUE composite index missing on streak_events '
                '(pragma_index_list returned: '
                '${pragmaRows.map((r) => r.data).toList()})',
          );
        },
      );

      // ── 2. EXPLAIN QUERY PLAN — SEARCH not SCAN ──────────────────────────

      test('dashboard completions query uses index, not table scan', () async {
        final plan = await explain(
          'SELECT * FROM completions '
          'WHERE profile_id = ? AND curriculum_id = ? '
          'ORDER BY completed_at DESC',
          variables: [Variable.withInt(1), Variable.withString('shas-bavli')],
        );
        expect(
          planUsesIndex(plan, 'completions'),
          isTrue,
          reason:
              'EXPLAIN should report SEARCH ... USING INDEX, not SCAN '
              'TABLE — got: $plan',
        );
      });

      test(
        'learning_ledger lifetime aggregation query uses index, not scan',
        () async {
          final plan = await explain(
            'SELECT * FROM learning_ledger '
            'WHERE profile_id = ? '
            'ORDER BY created_at',
            variables: [Variable.withInt(1)],
          );
          expect(
            planUsesIndex(plan, 'learning_ledger'),
            isTrue,
            reason:
                'EXPLAIN should report SEARCH ... USING INDEX, not SCAN '
                'TABLE — got: $plan',
          );
        },
      );

      test('streak_events query uses index, not table scan', () async {
        // Use only profileId — the index leading column must enable SEARCH.
        final plan = await explain(
          'SELECT * FROM streak_events WHERE profile_id = ?',
          variables: [Variable.withInt(1)],
        );
        expect(
          planUsesIndex(plan, 'streak_events'),
          isTrue,
          reason:
              'EXPLAIN should report SEARCH ... USING INDEX, not SCAN '
              'TABLE — got: $plan',
        );
      });
    },
  );

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

        setUp(() async {
          db = _createDb();
          await seedProfile(db);
        });
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

        setUp(() async {
          db = _createDb();
          await seedProfile(db);
        });
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
                  .insert(StreakEventsCompanion.insert(profileId: 1));
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
          processor = OutboxProcessor(
            outboxDao: dao,
            pipeline: mockPipeline,
            clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
          );

          // Default: pushCompletionsBatch succeeds and reports EVERY entry's
          // entityKey as committed (the H3 per-entry success contract — the
          // OutboxProcessor deletes exactly the rows whose entityKeys come
          // back, so the stub must echo the entityKeys of the entries it was
          // handed).
          when(
            () => mockPipeline.pushCompletionsBatch(
              profileId: any(named: 'profileId'),
              entries: any(named: 'entries'),
            ),
          ).thenAnswer((invocation) async {
            final entries =
                invocation.namedArguments[#entries]
                    as List<({String entityKey, Map<String, dynamic> payload})>;
            return entries.map((e) => e.entityKey).toList();
          });
        });

        tearDown(() => db.close());

        test('drain deletes rows that push successfully', () async {
          await dao.insertOutboxRow(_completionRow());

          final pushed = await processor.drain(1);

          expect(pushed, equals(1));
          final remaining = await db.select(db.outbox).get();
          expect(remaining, isEmpty);
        });

        test(
          'drain calls pushCompletionsBatch with correct arguments',
          () async {
            await dao.insertOutboxRow(_completionRow(entityKey: 'comp-abc'));

            await processor.drain(1);

            verify(
              () => mockPipeline.pushCompletionsBatch(
                profileId: 1,
                entries: any(named: 'entries'),
              ),
            ).called(1);
          },
        );

        test('drain marks row with error when push fails', () async {
          when(
            () => mockPipeline.pushCompletionsBatch(
              profileId: any(named: 'profileId'),
              entries: any(named: 'entries'),
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

            // Drain (device "reconnects") — all 50 cleared in a single batch call.
            final pushed = await processor.drain(1);

            expect(pushed, equals(50));
            final remaining = await db.select(db.outbox).get();
            expect(remaining, isEmpty);

            verify(
              () => mockPipeline.pushCompletionsBatch(
                profileId: 1,
                entries: any(named: 'entries'),
              ),
            ).called(1);
          },
        );

        test('drain clears all completion rows regardless of count', () async {
          // Insert 60 rows — completions have no per-drain cap; all are
          // dispatched in a single pushCompletionsBatch call.
          for (var i = 0; i < 60; i++) {
            await dao.insertOutboxRow(_completionRow(entityKey: 'comp-$i'));
          }

          final pushed = await processor.drain(1);

          expect(pushed, equals(60));
          final remaining = await db.select(db.outbox).get();
          expect(remaining, isEmpty);
        });

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

  // --------------------------------------------------------------------------
  // Story 26.14 — ContentTree indexed lookup (DNI-357)
  // --------------------------------------------------------------------------

  group('Story 26.14 — ContentTree indexed lookup', tags: ['story_26_14'], () {
    // ── children ─────────────────────────────────────────────────────────────

    group('ContentTree.children', () {
      test('empty stack returns top-level containers', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final roots = tree.children(CurriculumId.mishnayos, []);

        // Only the L1 container "Zeraim" has no deeper-level children at root
        expect(roots.any((i) => i.level1 == 'Zeraim'), isTrue);
      });

      test('depth-1 stack returns L2 children', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, ['Zeraim']);

        // Zeraim → Berakhot container
        expect(children.any((i) => i.level2 == 'Berakhot'), isTrue);
      });

      test('depth-3 stack returns leaf children', () {
        // The _smallCurriculumSet fixture has 4-level leaves (Zeraim/Berakhot/
        // Perek 1/Mishnah N) with no explicit L3 container.  ContentTree places
        // each leaf under its immediate parent path, so they appear at depth 3.
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, [
          'Zeraim',
          'Berakhot',
          'Perek 1',
        ]);

        // 4 mishnah leaves under Perek 1
        expect(children, isNotEmpty);
        expect(children.every((i) => i.isLeaf), isTrue);
        expect(children.every((i) => i.level3 == 'Perek 1'), isTrue);
      });

      test('unknown stack returns empty list (no crash)', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, ['NonExistent']);

        expect(children, isEmpty);
      });

      test('children are sorted by sortOrder', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // Use the depth-3 path which yields the 4 leaf items
        final children = tree.children(CurriculumId.mishnayos, [
          'Zeraim',
          'Berakhot',
          'Perek 1',
        ]);

        expect(children, isNotEmpty);
        final orders = children.map((i) => i.sortOrder).toList();
        final sorted = [...orders]..sort();
        expect(orders, equals(sorted));
      });

      test('does not cross curriculum boundaries', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final mishnayosRoots = tree.children(CurriculumId.mishnayos, []);
        final bavliRoots = tree.children(CurriculumId.bavli, []);

        expect(
          mishnayosRoots.every((i) => i.curriculumId == 'mishnayos'),
          isTrue,
        );
        expect(bavliRoots.every((i) => i.curriculumId == 'bavli'), isTrue);
      });
    });

    // ── parent ────────────────────────────────────────────────────────────────

    group('ContentTree.parent', () {
      test('parent of a leaf returns its container', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final p = tree.parent('Mishnah Berakhot 1:1');

        // Leaf is at level4 "Mishnah 1", parent container is "Perek 1"
        expect(p, isNotNull);
        expect(p!.curriculumId, equals('mishnayos'));
      });

      test('parent of a top-level container is null', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // 'Zeraim' is the root container — no parent
        final p = tree.parent('Zeraim');

        expect(p, isNull);
      });

      test('parent of unknown ref is null', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        expect(tree.parent('Made-up Ref'), isNull);
      });
    });

    // ── adjacent ──────────────────────────────────────────────────────────────

    group('ContentTree.adjacent (delegates to ContentIndex)', () {
      test('adjacent returns prev/next leaf within curriculum', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final adj = tree.adjacent('Mishnah Berakhot 1:2');

        expect(adj.prev?.sefariaRef, equals('Mishnah Berakhot 1:1'));
        expect(adj.next?.sefariaRef, equals('Mishnah Berakhot 1:3'));
      });

      test('adjacent does not cross curriculum boundaries', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // Last mishnayos leaf; next must be null
        final adj = tree.adjacent('Mishnah Berakhot 1:4');

        expect(adj.next, isNull);
      });
    });

    // ── containerFor ─────────────────────────────────────────────────────────

    group('ContentTree.containerFor', () {
      test('returns the container item for a known stack', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final container = tree.containerFor(CurriculumId.mishnayos, ['Zeraim']);

        expect(container, isNotNull);
        expect(container!.displayNameHe, equals('זרעים'));
      });

      test('returns null for an unknown stack', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        expect(
          tree.containerFor(CurriculumId.mishnayos, ['NonExistent']),
          isNull,
        );
      });
    });

    // ── ContentIndex.firstLeaf (added for DNI-357) ────────────────────────────

    group('ContentIndex.firstLeaf', () {
      test('returns the sefariaRef of the first leaf in sort order', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final ref = index.firstLeaf(CurriculumId.mishnayos);

        expect(ref, equals('Mishnah Berakhot 1:1'));
      });

      test('returns null for an unknown curriculum (no items)', () {
        // Build index without halachaDailyForSefardim
        final index = ContentIndex.fromCurricula({
          CurriculumId.mishnayos:
              _smallCurriculumSet()[CurriculumId.mishnayos]!,
        });

        // Any curriculum not in the map → null
        expect(index.firstLeaf(CurriculumId.bavli), isNull);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Story 25.10 — LocalDayClock single time provider (DNI-331)
  // --------------------------------------------------------------------------

  group('Story 25.10 — LocalDayClock single time provider', tags: ['story_25_10'], () {
    // ── 1. Interface contract ───────────────────────────────────────────────

    group('LocalDayClock contract', () {
      test('SystemLocalDayClock.nowUtc returns a UTC DateTime', () {
        const clock = SystemLocalDayClock();

        final now = clock.nowUtc();

        expect(now.isUtc, isTrue);
      });

      test('SystemLocalDayClock.today returns a y/m/d local DateTime', () {
        const clock = SystemLocalDayClock();

        final today = clock.today();
        final sysNow = DateTime.now();

        expect(today.isUtc, isFalse);
        expect(today.year, equals(sysNow.year));
        expect(today.month, equals(sysNow.month));
        expect(today.day, equals(sysNow.day));
        expect(today.hour, equals(0));
        expect(today.minute, equals(0));
        expect(today.second, equals(0));
        expect(today.millisecond, equals(0));
        expect(today.microsecond, equals(0));
      });

      test('FakeLocalDayClock returns the seeded UTC instant', () {
        final seeded = DateTime.utc(2026, 5, 13, 23, 30);
        final clock = FakeLocalDayClock(seeded);

        expect(clock.nowUtc(), equals(seeded));
      });

      test(
        'FakeLocalDayClock.today derives local date from seeded instant',
        () {
          // 2026-05-13 23:30 UTC == 2026-05-14 02:30 in Asia/Jerusalem (+3),
          // but we compute against whatever timezone the host runs in. The
          // contract is: today() == midnight-of-local-day of nowUtc.toLocal().
          final seeded = DateTime.utc(2026, 5, 13, 23, 30);
          final clock = FakeLocalDayClock(seeded);

          final today = clock.today();
          final expectedLocal = seeded.toLocal();

          expect(today.year, equals(expectedLocal.year));
          expect(today.month, equals(expectedLocal.month));
          expect(today.day, equals(expectedLocal.day));
          expect(today.hour, equals(0));
        },
      );

      test('FakeLocalDayClock.advance moves the clock forward', () {
        final seeded = DateTime.utc(2026, 5, 13, 10);
        final clock = FakeLocalDayClock(seeded);

        clock.advance(const Duration(hours: 6));

        expect(clock.nowUtc(), equals(DateTime.utc(2026, 5, 13, 16)));
      });

      test('FakeLocalDayClock.setNow replaces the current instant', () {
        final clock = FakeLocalDayClock(DateTime.utc(2026, 1, 1));

        clock.setNow(DateTime.utc(2026, 12, 31, 12));

        expect(clock.nowUtc(), equals(DateTime.utc(2026, 12, 31, 12)));
      });
    });

    // ── 2. Riverpod provider integration ────────────────────────────────────

    group('localDayClockProvider', () {
      test('default provider yields a SystemLocalDayClock', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final clock = container.read(localDayClockProvider);

        expect(clock, isA<SystemLocalDayClock>());
      });

      test('container override replaces the system clock with a fake', () {
        final fake = FakeLocalDayClock(DateTime.utc(2026, 5, 13, 23, 30));
        final container = ProviderContainer(
          overrides: [localDayClockProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final clock = container.read(localDayClockProvider);

        expect(identical(clock, fake), isTrue);
        expect(clock.nowUtc(), equals(DateTime.utc(2026, 5, 13, 23, 30)));
      });
    });

    // ── 3. Day-boundary determinism (NFR21 / T1.2 root cause) ───────────────

    group('day-boundary determinism', () {
      test(
        'today is read consistently when the clock is fixed, regardless of host TZ',
        () {
          // The contract: any code reading today() through the provider must
          // see the SAME (y, m, d) for a given fake instant, no matter where
          // the host runs. We pin the seed and assert the y/m/d derived from
          // it locally — this proves the clock-override IS the single source.
          final seeded = DateTime.utc(2026, 5, 13, 20, 30);
          final fake = FakeLocalDayClock(seeded);
          final container = ProviderContainer(
            overrides: [localDayClockProvider.overrideWithValue(fake)],
          );
          addTearDown(container.dispose);

          final today = container.read(localDayClockProvider).today();
          final expectedLocal = seeded.toLocal();

          expect(today.year, equals(expectedLocal.year));
          expect(today.month, equals(expectedLocal.month));
          expect(today.day, equals(expectedLocal.day));
        },
      );
    });

    // ── 4. No-rogue-DateTime-now invariant (AC: grep zero results) ──────────

    group('no-rogue-DateTime.now invariant', () {
      test(
        'grep "DateTime.now()" in lib/ outside core/time/ returns zero results',
        () {
          // AC: "grep -rn 'DateTime\\.now\\(\\)' lib/ --exclude-dir=core/time"
          // must return zero results. We run grep directly so the test fails
          // loudly the moment a new rogue DateTime.now() lands.
          final libDir = Directory('lib');
          expect(
            libDir.existsSync(),
            isTrue,
            reason:
                'test must run from learning_tracker/ (Flutter project root)',
          );

          final result = Process.runSync('grep', const [
            '-rn',
            'DateTime.now()',
            'lib/',
            '--exclude-dir=time',
          ]);

          // grep returns 1 when no matches found — that's the success case.
          expect(
            result.exitCode,
            equals(1),
            reason:
                'DateTime.now() is forbidden outside lib/core/time/. '
                'Use LocalDayClock via localDayClockProvider instead.\n'
                'Found:\n${result.stdout}',
          );
        },
      );
    });
  });

  // --------------------------------------------------------------------------
  // Story 25.7 — core/preferences/ ProfileScopedPreference primitives (DNI-328)
  // --------------------------------------------------------------------------

  group('Story 25.7 — ProfileScopedPreference primitives', tags: ['story_25_7'], () {
    setUp(() {
      // `SharedPreferences.getInstance` reads the platform channel; the in-memory
      // mock binding is required for tests that exercise the file boundary.
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('defaults — new profiles start with the AC-mandated values', () {
      test(
        // Updated by fix(issue-7a): new profiles default to Hebrew script/calendar
        'HebrewTermsPreference defaults to true (Hebrew script on first launch)',
        () async {
          final pref = HebrewTermsPreference();
          expect(pref.defaultValue, isTrue);
          expect(await pref.read(0), isTrue);
          expect(await pref.read(7), isTrue);
          await pref.dispose();
        },
      );

      test(
        // Updated by fix(issue-7a): new profiles default to Hebrew calendar
        'HebrewDatePreference defaults to true (Hebrew calendar on first launch)',
        () async {
          final pref = HebrewDatePreference();
          expect(pref.defaultValue, isTrue);
          expect(await pref.read(0), isTrue);
          expect(await pref.read(7), isTrue);
          await pref.dispose();
        },
      );

      test('NikudPreference defaults to true (pointed text on)', () async {
        final pref = NikudPreference();
        expect(pref.defaultValue, isTrue);
        expect(await pref.read(0), isTrue);
        await pref.dispose();
      });

      test('AppLocalePreference defaults to en', () async {
        final pref = AppLocalePreference();
        expect(pref.defaultValue, const Locale('en'));
        expect(await pref.read(0), const Locale('en'));
        await pref.dispose();
      });

      test('TransliterationVariantPreference defaults to ashkenazi', () async {
        final pref = TransliterationVariantPreference();
        expect(pref.defaultValue, TransliterationVariant.ashkenazi);
        expect(await pref.read(0), TransliterationVariant.ashkenazi);
        await pref.dispose();
      });

      test('TextDisplayPreference defaults to FontSize.medium', () async {
        final pref = TextDisplayPreference();
        expect(pref.defaultValue, FontSize.medium);
        expect(await pref.read(0), FontSize.medium);
        await pref.dispose();
      });
    });

    group('per-profile isolation — writes do not leak across profiles', () {
      test('writing for profile A does not affect profile B (bool)', () async {
        final pref = HebrewTermsPreference();
        await pref.write(
          1,
          false,
        ); // explicitly write false so profile 2's true default is distinct
        expect(await pref.read(1), isFalse);
        expect(
          await pref.read(2),
          isTrue,
          reason: 'profile 2 must keep its default (true since fix(issue-7a))',
        );
        await pref.dispose();
      });

      test(
        'writing for profile A does not affect profile B (string-coded enum)',
        () async {
          final pref = TransliterationVariantPreference();
          await pref.write(1, TransliterationVariant.sephardi);
          expect(await pref.read(1), TransliterationVariant.sephardi);
          expect(await pref.read(2), TransliterationVariant.ashkenazi);
          await pref.dispose();
        },
      );

      test(
        'writing for profile A does not affect profile B (int-coded enum)',
        () async {
          final pref = TextDisplayPreference();
          await pref.write(1, FontSize.large);
          expect(await pref.read(1), FontSize.large);
          expect(await pref.read(2), FontSize.medium);
          await pref.dispose();
        },
      );

      test(
        'writing for profile A does not affect profile B (Locale)',
        () async {
          final pref = AppLocalePreference();
          await pref.write(1, const Locale('he'));
          expect(await pref.read(1), const Locale('he'));
          expect(await pref.read(2), const Locale('en'));
          await pref.dispose();
        },
      );
    });

    group('round-trip — read after write returns the written value', () {
      test('HebrewTermsPreference', () async {
        final pref = HebrewTermsPreference();
        await pref.write(0, true);
        expect(await pref.read(0), isTrue);
        await pref.write(0, false);
        expect(await pref.read(0), isFalse);
        await pref.dispose();
      });

      test('HebrewDatePreference', () async {
        final pref = HebrewDatePreference();
        await pref.write(3, true);
        expect(await pref.read(3), isTrue);
        await pref.dispose();
      });

      test('NikudPreference', () async {
        final pref = NikudPreference();
        await pref.write(0, false);
        expect(await pref.read(0), isFalse);
        await pref.dispose();
      });

      test('AppLocalePreference', () async {
        final pref = AppLocalePreference();
        await pref.write(0, const Locale('he'));
        expect(await pref.read(0), const Locale('he'));
        await pref.dispose();
      });

      test('TransliterationVariantPreference', () async {
        final pref = TransliterationVariantPreference();
        await pref.write(0, TransliterationVariant.sephardi);
        expect(await pref.read(0), TransliterationVariant.sephardi);
        await pref.dispose();
      });

      test('TextDisplayPreference', () async {
        final pref = TextDisplayPreference();
        await pref.write(0, FontSize.small);
        expect(await pref.read(0), FontSize.small);
        await pref.dispose();
      });
    });

    group('observe — every write reaches the matching profile stream', () {
      test(
        'observers see writes for the requested profile and ignore others',
        () async {
          final pref = HebrewTermsPreference();
          final fromProfile1 = <bool>[];
          final fromProfile2 = <bool>[];
          final sub1 = pref.observe(1).listen(fromProfile1.add);
          final sub2 = pref.observe(2).listen(fromProfile2.add);
          await pref.write(1, true);
          await pref.write(2, true);
          await pref.write(1, false);
          // Allow microtasks to drain.
          await Future<void>.delayed(Duration.zero);
          expect(fromProfile1, equals([true, false]));
          expect(fromProfile2, equals([true]));
          await sub1.cancel();
          await sub2.cancel();
          await pref.dispose();
        },
      );

      test('every primitive exposes a working observe stream', () async {
        // Smoke test all six primitives share the same `(read, write, observe)`
        // contract.
        final cases = <ProfileScopedPreference<Object>>[
          HebrewTermsPreference(),
          HebrewDatePreference(),
          NikudPreference(),
          AppLocalePreference(),
          TransliterationVariantPreference(),
          TextDisplayPreference(),
        ];
        try {
          for (final pref in cases) {
            final seen = <Object>[];
            final sub = pref.observe(5).listen(seen.add);
            await pref.write(5, _flippedValue(pref));
            await Future<void>.delayed(Duration.zero);
            expect(
              seen,
              hasLength(1),
              reason: '${pref.runtimeType} did not notify observers',
            );
            await sub.cancel();
          }
        } finally {
          for (final p in cases) {
            await p.dispose();
          }
        }
      });
    });

    test(
      'profile-switch scenario — preference resolves to the new profile value',
      () async {
        // AC: "When the user switches profiles, the new profile loads its own
        // preference values (no global leakage)."
        final pref = HebrewTermsPreference();
        await pref.write(1, true);
        await pref.write(2, false);
        // Active profile starts at 1.
        expect(await pref.read(1), isTrue);
        // Switching to profile 2 must see its own stored value, not profile 1's.
        expect(await pref.read(2), isFalse);
        // Switching back to profile 1 still sees true.
        expect(await pref.read(1), isTrue);
        await pref.dispose();
      },
    );

    test(
      'storage key contract — writes land at `<key>_p<profileId>` so they survive a fresh read',
      () async {
        final pref = HebrewTermsPreference();
        await pref.write(42, true);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.hebrewTermsScript(42)),
          isTrue,
          reason: 'Writes must use the profile-scoped key namespace',
        );
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.hebrewTermsScript(0)),
          isNull,
          reason: 'profile 0 row must remain absent',
        );
        await pref.dispose();
      },
    );
  });

  // --------------------------------------------------------------------------
  // Story 25.19 — Finalize AppLogger; migrate remaining production logs (DNI-340)
  // --------------------------------------------------------------------------

  group(
    'Story 25.19 — Finalize AppLogger and migrate remaining production logs',
    tags: ['story_25_19'],
    () {
      // ── AC: no debugPrint / bare print() outside generated files ────────────

      test(
        'grep debugPrint|print() in lib/ returns zero non-generated results',
        () {
          final libDir = Directory('lib');
          expect(
            libDir.existsSync(),
            isTrue,
            reason:
                'test must run from learning_tracker/ (Flutter project root)',
          );

          // One single piped pipeline: grep for debugPrint/bare-print, strip
          // generated files and core/logging/ (where AppLogger lives).
          // Raw string keeps backslashes (\|, \., \s) destined for the shell.
          const cmd =
              r"""grep -rn 'debugPrint\|^\s*print(' lib/ --include='*.dart' | grep -v '\.g\.dart' | grep -v '\.freezed\.dart' | grep -v 'core/logging/' || true""";
          final result = Process.runSync('bash', const ['-c', cmd]);

          final stdout = (result.stdout as String).trim();
          expect(
            stdout,
            isEmpty,
            reason:
                'debugPrint() and bare print() are forbidden outside '
                'core/logging/. Use AppLogger.info/.debug/.warning/.error '
                'with the named-param API instead.\nFound:\n$stdout',
          );
        },
      );

      // ── AC: no raw `package:talker/talker.dart` import outside core/logging/

      test('grep raw package:talker/talker.dart import outside core/logging/ '
          'returns zero results', () {
        final libDir = Directory('lib');
        expect(libDir.existsSync(), isTrue);

        final result = Process.runSync('grep', const [
          '-rn',
          "import 'package:talker/talker.dart'",
          'lib/',
          '--exclude-dir=logging',
        ]);

        // grep exits 1 when no matches — that is the green case.
        expect(
          result.exitCode,
          equals(1),
          reason:
              "Raw `import 'package:talker/talker.dart'` is forbidden "
              'outside lib/core/logging/. Inject an `AppLogger` instead '
              '(or use `talker_flutter` when a raw Talker is genuinely '
              'required by a third-party widget).\nFound:\n${result.stdout}',
        );
      });

      // ── AC: structured-event shape — the field-based redactor is applied ────

      test('AppLogger.info(event:, fields:) builds {event field=value} message '
          'and redacts sensitive keys', () {
        final talker = Talker(
          settings: TalkerSettings(
            enabled: true,
            useConsoleLogs: false,
            maxHistoryItems: 16,
          ),
        );
        final log = AppLogger(talker);

        log.info(
          event: 'sync_pull_completed',
          fields: const {
            'profileId': 7,
            'durationMs': 142,
            'status': 'ok',
            'email': 'leak@example.com',
          },
        );

        // Wait until Talker drains its internal queue.
        final entry = talker.history.firstWhere(
          (e) => (e.message ?? '').startsWith('sync_pull_completed'),
        );
        final msg = entry.message ?? '';

        // event prefix preserved verbatim
        expect(msg, startsWith('sync_pull_completed '));
        // non-sensitive fields preserved
        expect(msg, contains('profileId: 7'));
        expect(msg, contains('durationMs: 142'));
        expect(msg, contains('status: ok'));
        // sensitive value redacted by key
        expect(msg, contains('email: [REDACTED]'));
        expect(msg, isNot(contains('leak@example.com')));
      });

      // ── AC: DeviceRestoreService consumes an AppLogger (not raw Talker) ─────

      test(
        'DeviceRestoreService constructor takes AppLogger (DI surface migrated)',
        () {
          // Inspect the source file directly — we don't want this test to need
          // a full Firebase/Drift environment. Source-level inspection is
          // sufficient to confirm the constructor signature has been migrated.
          final file = File(
            'lib/features/sync/domain/services/device_restore_service.dart',
          );
          expect(file.existsSync(), isTrue);

          final src = file.readAsStringSync();
          expect(
            src,
            contains('required AppLogger logger'),
            reason:
                'DeviceRestoreService must now take `AppLogger logger`, '
                'not `Talker logger`.',
          );
          expect(
            src,
            isNot(contains("import 'package:talker/talker.dart'")),
            reason:
                'DeviceRestoreService must not import package:talker/talker '
                'directly — depend on AppLogger.',
          );
        },
      );

      test(
        'SeedManager and ContentDbHealthChecker constructors take AppLogger',
        () {
          final seed = File(
            'lib/core/database/seed_manager.dart',
          ).readAsStringSync();
          expect(
            seed,
            contains('AppLogger? logger'),
            reason: 'SeedManager must accept an optional AppLogger.',
          );
          expect(seed, isNot(contains("import 'package:talker/talker.dart'")));

          final hc = File(
            'lib/core/database/content_db_health_checker.dart',
          ).readAsStringSync();
          expect(
            hc,
            contains('AppLogger? logger'),
            reason: 'ContentDbHealthChecker must accept an optional AppLogger.',
          );
          expect(hc, isNot(contains("import 'package:talker/talker.dart'")));
        },
      );

      test(
        'completion_dao cross-profile breadcrumb uses AppLogger, not debugPrint',
        () {
          final dao = File(
            'lib/core/database/daos/completion_dao.dart',
          ).readAsStringSync();
          expect(
            dao,
            isNot(contains('debugPrint(')),
            reason:
                'CompletionDao._assertCrossProfileScope must emit through '
                'AppLogger.warning(event: ..., fields: {...}).',
          );
          expect(
            dao,
            contains("event: 'cross_profile_read'"),
            reason:
                'Cross-profile breadcrumbs must use the structured '
                '`cross_profile_read` event name (NFR7).',
          );
        },
      );
    },
  );

  // --------------------------------------------------------------------------
  // Story 25.17 — BaseDao<T> + TrackScope; delete cross-profile DAO methods
  // (DNI-338)
  // --------------------------------------------------------------------------
  group(
    'Story 25.17 — BaseDao + TrackScope; cross-profile DAO methods deleted',
    tags: ['story_25_17'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
      });
      tearDown(() => db.close());

      // AC: TrackScope is a freezed record threaded through track-aware
      //     queries.
      test('TrackScope exposes profileId, trackId, curriculumId fields', () {
        const scope = TrackScope(
          profileId: 7,
          trackId: 3,
          curriculumId: CurriculumId.mishnayos,
        );
        expect(scope.profileId, 7);
        expect(scope.trackId, 3);
        expect(scope.curriculumId, CurriculumId.mishnayos);
      });

      test('TrackScope has freezed value equality', () {
        const a = TrackScope(
          profileId: 1,
          trackId: 2,
          curriculumId: CurriculumId.mishnayos,
        );
        const b = TrackScope(
          profileId: 1,
          trackId: 2,
          curriculumId: CurriculumId.mishnayos,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      // AC: BaseDao<T> is a Dart mixin offering getById, getByProfile,
      //     count, exists.
      test(
        'BaseDao<T> mixin provides count/exists/getById/getByProfile',
        () async {
          await db.streakEventDao.upsertStreakByProfile(
            1,
            StreakEventsCompanion.insert(
              profileId: 1,
              currentStreak: const Value(5),
            ),
          );
          await db.streakEventDao.upsertStreakByProfile(
            2,
            StreakEventsCompanion.insert(
              profileId: 2,
              currentStreak: const Value(3),
            ),
          );

          expect(await db.streakEventDao.count(profileId: 1), 1);
          expect(await db.streakEventDao.exists(profileId: 1), isTrue);
          expect(await db.streakEventDao.count(profileId: 99), 0);
          expect(await db.streakEventDao.exists(profileId: 99), isFalse);

          final byProfile = await db.streakEventDao.getByProfile(1);
          expect(byProfile, hasLength(1));
          expect(byProfile.first.profileId, 1);

          final byId = await db.streakEventDao.getById(byProfile.first.id);
          expect(byId, isNotNull);
          expect(byId!.profileId, 1);
        },
      );

      // AC: The 6 cross-profile methods on CompletionDao are deleted (from
      //     the public surface).
      test('public cross-profile CompletionDao methods are deleted', () {
        // The methods listed below were public on CompletionDao before
        // DNI-338. They must no longer be reachable — `dynamic` lookups
        // throw [NoSuchMethodError] when the method does not exist.
        final dao = db.completionDao as dynamic;
        for (final name in const [
          'getAllCompletions',
          'getCompletionsByCurriculum',
          'getCompletionsForContent',
          'getCompletionsByDateRange',
          'hasCompletionsInDateRange',
          'getTrackBreakdown',
          'getAggregateCount',
        ]) {
          expect(
            () {
              switch (name) {
                case 'getAllCompletions':
                  return dao.getAllCompletions();
                case 'getCompletionsByCurriculum':
                  return dao.getCompletionsByCurriculum('x');
                case 'getCompletionsForContent':
                  return dao.getCompletionsForContent('x');
                case 'getCompletionsByDateRange':
                  return dao.getCompletionsByDateRange(
                    DateTime.utc(2026),
                    DateTime.utc(2026, 2),
                  );
                case 'hasCompletionsInDateRange':
                  return dao.hasCompletionsInDateRange(
                    DateTime.utc(2026),
                    DateTime.utc(2026, 2),
                  );
                case 'getTrackBreakdown':
                  return dao.getTrackBreakdown('x');
                case 'getAggregateCount':
                  return dao.getAggregateCount('x');
              }
            },
            throwsA(isA<NoSuchMethodError>()),
            reason: 'CompletionDao.$name should be deleted from public surface',
          );
        }
      });

      // AC: Cross-profile aggregation goes through parentAnalyticsRepository.
      test('ParentAnalyticsRepository is the public surface for '
          'cross-profile reads', () async {
        // Seed a curriculum track (id=1) and a second profile (id=2).
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                trackType: 'personal',
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: 1,
                displayName: 'Test User 2',
                mode: 'adult',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'r1',
            stageId: 1,
            trackType: 'forwards',
            trackId: 1,
            completedAt: DateTime.utc(2026, 5, 13),
          ),
        );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 2,
            curriculumId: 'mishnayos',
            sefariaRef: 'r2',
            stageId: 1,
            trackType: 'forwards',
            trackId: 1,
            completedAt: DateTime.utc(2026, 5, 13),
          ),
        );

        final repo = ParentAnalyticsRepositoryImpl(db);
        final all = await repo.getAllCompletions(
          scope: CrossProfileScope.parentAnalytics,
        );
        expect(all, hasLength(2));
        expect(all.map((c) => c.profileId).toSet(), equals({1, 2}));
      });
    },
  );
}

Object _flippedValue(ProfileScopedPreference<Object> pref) {
  if (pref is HebrewTermsPreference ||
      pref is HebrewDatePreference ||
      pref is NikudPreference) {
    return !(pref.defaultValue as bool);
  }
  if (pref is AppLocalePreference) {
    return const Locale('he');
  }
  if (pref is TransliterationVariantPreference) {
    return TransliterationVariant.sephardi;
  }
  if (pref is TextDisplayPreference) {
    return FontSize.large;
  }
  throw StateError('Unhandled preference type: ${pref.runtimeType}');
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
