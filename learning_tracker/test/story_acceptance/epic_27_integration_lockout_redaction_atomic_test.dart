/// Story acceptance tests for Epic 27 — Story 27.9 (DNI-385):
/// Integration regression tests for three NFR13 pitfalls:
///   * AC1 — PIN lockout full cycle: 5 failed attempts trigger a 15-minute
///           cooldown; attempts during the cooldown are rejected; an attempt
///           after the cooldown succeeds.
///   * AC2 — Structured log redaction: values for keys in
///           `PiiRedactor.sensitiveKeys` are replaced with `[REDACTED]`;
///           the `event` string is preserved verbatim (no substring scan).
///   * AC3 — Bookmark-advance atomicity: when a completion insert and a
///           bookmark advance share one Drift transaction, throwing in the
///           bookmark step rolls back the completion.
@Tags(['epic_27'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, expectLater, group, setUp, tearDown, test;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedProfile;

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// In-memory secure-storage stub keyed by string. Mirrors the pattern from
/// `test/features/parent_mode/pin_service_test.dart`.
_MockSecureStorage _createInMemorySecureStorage() {
  final mock = _MockSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });
  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });
  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

void main() {
  // ── AC1: PIN lockout full cycle ────────────────────────────────────────────

  group(
    'Story 27.9 — AC1: PIN lockout cycle (5 bad → cooldown → expire → success)',
    tags: ['story_27_9'],
    () {
      late FakeLocalDayClock fakeClock;
      late _MockSecureStorage storage;
      late PinService pinService;

      setUp(() async {
        // Seed at a fixed instant; PinService reads through DateTimeFactory
        // which goes through `currentLocalDayClock`.
        fakeClock = FakeLocalDayClock(DateTime.utc(2026, 5, 13, 12));
        useLocalDayClock(fakeClock);

        storage = _createInMemorySecureStorage();
        pinService = PinService(
          storage,
          // Defaults that the production service uses — pinned here so the
          // test is self-documenting and survives a default change.
          maxFailedAttempts: 5,
          lockoutDurationMinutes: 15,
        );
        await pinService.setParentPin('1234');
      });

      tearDown(() {
        resetLocalDayClock();
      });

      test('5 failed attempts trigger the 15-minute cooldown — '
          'next attempt throws PinLockoutException', () async {
        // 5 wrong PINs — the fifth flips the service into lockout.
        for (var i = 0; i < 5; i++) {
          expect(await pinService.verifyParentPin('0000'), isFalse);
        }
        // Even the *correct* PIN is rejected while the cooldown is active.
        await expectLater(
          pinService.verifyParentPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
        final remaining = await pinService.getParentLockoutRemainingMinutes();
        expect(remaining, equals(15));
      });

      test('attempts during the cooldown window are rejected — '
          'tested at the boundary (14m59s after lockout)', () async {
        for (var i = 0; i < 5; i++) {
          await pinService.verifyParentPin('0000');
        }

        // Advance to 14m59s — still inside the 15-minute window.
        fakeClock.advance(const Duration(minutes: 14, seconds: 59));
        await expectLater(
          pinService.verifyParentPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
      });

      test(
        'the correct PIN is accepted once the 15-minute cooldown elapses',
        () async {
          for (var i = 0; i < 5; i++) {
            await pinService.verifyParentPin('0000');
          }

          // Step exactly 15 minutes — boundary check (`isBefore` is strict).
          fakeClock.advance(const Duration(minutes: 15));
          expect(await pinService.verifyParentPin('1234'), isTrue);

          // Successful verification clears the lockout state in storage —
          // a fresh counter starts; 4 bad PINs must NOT re-trigger lockout.
          for (var i = 0; i < 4; i++) {
            expect(await pinService.verifyParentPin('0000'), isFalse);
          }
        },
      );
    },
  );

  // ── AC2: Structured log redaction ──────────────────────────────────────────

  group(
    'Story 27.9 — AC2: structured log redaction by field-key allowlist',
    tags: ['story_27_9'],
    () {
      late Talker talker;
      late AppLogger logger;

      setUp(() {
        // A fresh Talker per test so history assertions are deterministic.
        talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
        logger = AppLogger(talker);
      });

      String lastMessage() => talker.history.last.generateTextMessage();

      test('event string is preserved verbatim — '
          '`PIN setup screen opened` is NOT redacted by substring match', () {
        logger.info(event: 'PIN setup screen opened');
        // The event text contains the word "PIN" — the legacy bug used a
        // substring scan that would have redacted the whole line. The new
        // redactor matches *keys*, never message content.
        expect(lastMessage(), contains('PIN setup screen opened'));
        expect(lastMessage(), isNot(contains('[REDACTED]')));
      });

      test(
        'sensitive field values are redacted; non-sensitive values pass through',
        () {
          logger.info(
            event: 'auth_login_attempt',
            fields: {
              'userEmail': 'user@example.com',
              'count': 3,
              'success': false,
            },
          );
          final msg = lastMessage();

          // Event name preserved verbatim.
          expect(msg, contains('auth_login_attempt'));
          // Sensitive key value redacted.
          expect(msg, contains('[REDACTED]'));
          expect(msg, isNot(contains('user@example.com')));
          // Non-sensitive keys and their literal values survive.
          expect(msg, contains('count'));
          expect(msg, contains('3'));
          expect(msg, contains('success'));
          expect(msg, contains('false'));
        },
      );

      test('every key in PiiRedactor.sensitiveKeys is redacted', () {
        // Build a fields map containing every sensitive key — values are
        // unique markers so we can confirm none of them leaks into the
        // rendered log line.
        final fields = <String, dynamic>{
          for (final k in PiiRedactor.sensitiveKeys) k: 'SENSITIVE_$k',
        };
        logger.info(event: 'sensitive_field_sweep', fields: fields);
        final msg = lastMessage();

        for (final k in PiiRedactor.sensitiveKeys) {
          expect(
            msg,
            isNot(contains('SENSITIVE_$k')),
            reason: 'Key "$k" value must be redacted in log output.',
          );
        }
        // Event itself is intact.
        expect(msg, contains('sensitive_field_sweep'));
      });

      test(
        'legacy string API still scrubs bare email addresses from messages',
        () {
          logger.infoMsg('Logged in as user@example.com');
          final msg = lastMessage();
          expect(msg, contains('[REDACTED]'));
          expect(msg, isNot(contains('user@example.com')));
        },
      );
    },
  );

  // ── AC3: Bookmark advance atomicity ────────────────────────────────────────
  //
  // The bookmark advance must share one Drift transaction with the completion
  // insert so a failure in the advance rolls the completion back. The
  // production wire-up lives in `CompletionRepositoryImpl` (today the advance
  // is *outside* the transaction — DNI-385 ratifies the invariant the wire-up
  // must satisfy). The test below verifies Drift's primitive guarantee — once
  // production code wraps `advanceBookmark` in `db.transaction(...)`, the
  // same `Future.error` rollback behaviour kicks in.

  group(
    'Story 27.9 — AC3: bookmark advance atomicity (transaction rollback)',
    tags: ['story_27_9'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
        // Insert one curriculum track row so the completion FK resolves —
        // see DNI-336 (CompletionWriter) test for the same helper.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnah_yomit',
                stateChangedAt: DateTime.utc(2026, 5, 1),
                activatedAt: DateTime.utc(2026, 5, 1),
              ),
            );
      });
      tearDown(() async => db.close());

      Future<void> commitWithSimulatedBookmarkAdvance({
        required bool bookmarkAdvanceThrows,
      }) {
        // One transaction wraps BOTH the completion insert AND the bookmark
        // advance — the contract that production code must mirror.
        return db.transaction(() async {
          await db
              .into(db.completionEvents)
              .insert(
                CompletionEventsCompanion.insert(
                  profileId: 1,
                  curriculumId: 'mishnah_yomit',
                  sefariaRef: 'Mishnah Berakhot 1',
                  stageId: 1,
                  trackType: 'personal',
                  trackId: Value(1),
                  eventTimestamp: DateTime.utc(2026, 5, 13, 12),
                ),
              );
          if (bookmarkAdvanceThrows) {
            throw StateError('simulated bookmark-advance failure');
          }
          // Real bookmark advance would happen here.
        });
      }

      Future<int> countCompletions() async {
        final rows = await db.select(db.completionEvents).get();
        return rows.length;
      }

      test(
        'completion is rolled back when the bookmark advance throws',
        () async {
          await expectLater(
            commitWithSimulatedBookmarkAdvance(bookmarkAdvanceThrows: true),
            throwsA(isA<StateError>()),
          );
          expect(
            await countCompletions(),
            equals(0),
            reason:
                'Drift must roll the completion insert back when any '
                'statement inside the transaction throws — this is the '
                'invariant the bookmark-advance wire-up depends on.',
          );
        },
      );

      test(
        'completion is persisted when the bookmark advance succeeds',
        () async {
          await commitWithSimulatedBookmarkAdvance(
            bookmarkAdvanceThrows: false,
          );
          expect(await countCompletions(), equals(1));
        },
      );
    },
  );
}
