/// Story acceptance tests for Epic 27 — Story 27.9 (DNI-385):
/// Integration regression tests for three NFR13 pitfalls:
///   * AC1 — PIN lockout full cycle: 5 failed attempts trigger a 15-minute
///           cooldown; attempts during the cooldown are rejected; an attempt
///           after the cooldown succeeds.
///   * AC2 — Structured log redaction: values for keys in
///           `PiiRedactor.sensitiveKeys` are replaced with `[REDACTED]`;
///           the `event` string is preserved verbatim (no substring scan).
///   * AC3 — Bookmark-advance failure handling: an injected `BookmarkRepository`
///           fake that throws must NOT roll back or fail the completion write.
///           Superseded by the completion-orchestrator lift
///           (`docs/firestore-rewrite-map.md`, owner decision 1, 2026-08-03):
///           bookmark advance moved out of `CompletionRepositoryImpl`'s Drift
///           transaction into `CompletionOrchestrator`'s post-write,
///           independently-caught side effects — see that class's doc
///           comment, "Regression this lift knowingly accepts," for why the
///           original transactional rollback guarantee (AUD-t-story-
///           acceptance-01) was intentionally NOT reproduced: Firestore
///           cannot offer the same guarantee, and this orchestrator is meant
///           to behave identically above either storage backend.
@Tags(['epic_27'])
library;

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, expectLater, group, setUp, setUpAll, tearDown, test;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedProfile;
import '../helpers/fake_clock.dart';

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// AC3 fake — stands in for the production `BookmarkRepository` injected
/// into `CompletionRepositoryImpl`. Its `advanceBookmark` is stubbed per
/// test (throw / succeed); every other member is intentionally left
/// unstubbed because `markComplete`'s tested code path never calls it.
class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

/// AC3 fake — `CompletionRepositoryImpl` requires a non-null
/// `ContentRepository` at construction, but the `markComplete` path under
/// test never reaches it: the injected `_MockBookmarkRepository` above
/// satisfies `_advanceBookmark` directly, and `_completionDetectionService`
/// is left null so the siyum-detection call site is skipped. Left entirely
/// unstubbed on purpose — any unexpected call fails loudly via mocktail's
/// `MissingStubError` rather than silently returning bogus content.
class _MockContentRepository extends Mock implements ContentRepository {}

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
        fakeClock = installFakeClock(DateTime.utc(2026, 5, 13, 12));

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
  // insert so a failure in the advance does NOT roll the completion back
  // (post completion-orchestrator lift — see the file doc comment's AC3
  // entry). This drives the REAL production wire-up —
  // `CompletionOrchestrator.markComplete` over a real
  // `CompletionRepositoryImpl`, constructed with an injected
  // `BookmarkRepository` fake — instead of a hand-rolled `db.transaction()`
  // that would only prove Drift's rollback primitive (AUD-t-story-
  // acceptance-01 / TQ-8's original intent, now testing the deliberately
  // opposite contract).

  group(
    'Story 27.9 — AC3: bookmark-advance failure does not roll back the '
    'completion',
    tags: ['story_27_9'],
    () {
      late UserDatabase db;
      late int profileId;

      const curriculumId = 'mishnayos';
      const request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: 'Mishnah Berakhot 1',
        stageId: 1,
        trackType: 'personal',
      );

      setUpAll(() {
        registerFallbackValue(CurriculumId.mishnayos);
      });

      setUp(() async {
        // Fresh Talker per test — CompletionOrchestrator logs a caught
        // bookmark-advance failure via AppLogger, and the first test below
        // asserts on that log history.
        AppLogger.init();

        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
        // seedProfile inserts exactly one account + one learner profile —
        // its id is deterministic (autoincrement from a fresh in-memory db).
        final profile = await db.select(db.learnerProfiles).getSingle();
        profileId = profile.id;

        // Curriculum track row so `CompletionRepositoryImpl._resolveTrackId`
        // resolves — see DNI-336 (CompletionWriter) test for the same
        // helper.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                stateChangedAt: DateTime.utc(2026, 5, 1),
                activatedAt: DateTime.utc(2026, 5, 1),
              ),
            );
      });
      tearDown(() async => db.close());

      Future<int> countCompletions() async {
        final rows = await db.select(db.completionEvents).get();
        return rows.length;
      }

      /// Builds the real [CompletionOrchestrator] under test, over a real
      /// (storage-only) [CompletionRepositoryImpl], wired with
      /// [bookmarkRepo] the same way `completionOrchestratorProvider` wires
      /// its production `BookmarkRepository`.
      CompletionOrchestrator buildOrchestrator(
        BookmarkRepository bookmarkRepo,
      ) {
        final repository = CompletionRepositoryImpl(
          database: db,
          activeProfileId: profileId,
        );
        return CompletionOrchestrator(
          repository: repository,
          contentRepository: _MockContentRepository(),
          bookmarkRepository: bookmarkRepo,
          activeProfileId: profileId,
        );
      }

      test(
        'completion is persisted (not rolled back) when the real '
        'bookmark-advance wiring throws, and the failure is logged',
        () async {
          final bookmarkRepo = _MockBookmarkRepository();
          when(
            () => bookmarkRepo.advanceBookmark(
              curriculumId: any(named: 'curriculumId'),
              completedSefariaRef: any(named: 'completedSefariaRef'),
            ),
          ).thenThrow(StateError('simulated bookmark-advance failure'));

          final orchestrator = buildOrchestrator(bookmarkRepo);

          // Must NOT throw — CompletionOrchestrator catches and logs every
          // post-write side effect independently (see its class doc comment,
          // "Ordering"), so a bookmark-advance failure never surfaces to the
          // caller or blocks the already-durable completion write.
          final result = await orchestrator.markComplete(request);

          expect(result.completion.sefariaRef, equals(request.sefariaRef));
          expect(
            await countCompletions(),
            equals(1),
            reason:
                'A completion is permanent once written (owner decision, '
                'docs/firestore-rewrite-map.md) — a downstream bookmark-'
                'advance failure must never retract it. Post completion-'
                'orchestrator lift this is deliberately NOT a rollback '
                'boundary any more; see CompletionOrchestrator\'s doc '
                'comment, "Regression this lift knowingly accepts."',
          );

          final history = AppLogger.instance.talker.history
              .map((e) => e.generateTextMessage())
              .toList();
          expect(
            history.any(
              (m) => m.contains('completion_bookmark_advance_failed'),
            ),
            isTrue,
            reason:
                'The caught bookmark-advance failure must be logged via '
                'AppLogger instead of silently dropped. '
                'Talker history: $history',
          );
        },
      );

      test('completion is persisted through the real orchestrator wiring '
          'when the bookmark advance succeeds', () async {
        final bookmarkRepo = _MockBookmarkRepository();
        when(
          () => bookmarkRepo.advanceBookmark(
            curriculumId: any(named: 'curriculumId'),
            completedSefariaRef: any(named: 'completedSefariaRef'),
          ),
        ).thenAnswer((_) async {});

        final orchestrator = buildOrchestrator(bookmarkRepo);

        final result = await orchestrator.markComplete(request);

        expect(result.completion.sefariaRef, equals(request.sefariaRef));
        expect(await countCompletions(), equals(1));
        verify(
          () => bookmarkRepo.advanceBookmark(
            curriculumId: CurriculumId.mishnayos,
            completedSefariaRef: request.sefariaRef,
          ),
        ).called(1);
      });
    },
  );
}
