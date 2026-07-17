import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

const _chartDataServicePath =
    'lib/features/progress/domain/services/chart_data_service.dart';

/// Extracts the implementation of a method named [methodName] from Dart
/// [source] — either the expression body of an arrow function (`=> expr;`)
/// or the statement block of a `{ ... }` body. Search starts at the `})`
/// that closes the method's named-parameter list, so it works for both
/// forms without needing a full Dart parser.
///
/// Used by the AUD-progress-05 regression test below to assert structurally
/// that `getCumulativeProgressLive` delegates to `getCumulativeProgress`
/// rather than carrying its own independent copy of the query/bucketing
/// logic (Fowler duplicated code).
String _extractMethodImpl(String source, String methodName) {
  final sigIndex = source.indexOf('$methodName(');
  if (sigIndex == -1) {
    fail('$methodName not found in $_chartDataServicePath');
  }

  final paramsEnd = source.indexOf('})', sigIndex);
  if (paramsEnd == -1) {
    fail('could not find end of parameter list for $methodName');
  }

  var i = paramsEnd + 2; // just after '})'
  while (source[i] == ' ' || source[i] == '\n') {
    i++;
  }
  if (source.startsWith('async', i)) {
    i += 'async'.length;
    while (source[i] == ' ' || source[i] == '\n') {
      i++;
    }
  }

  if (source[i] == '=' && source[i + 1] == '>') {
    // Arrow-function body: read until the statement-terminating ';' at
    // bracket depth 0.
    var j = i + 2;
    var depth = 0;
    while (!(depth == 0 && source[j] == ';')) {
      if (source[j] == '(' || source[j] == '{' || source[j] == '[') depth++;
      if (source[j] == ')' || source[j] == '}' || source[j] == ']') depth--;
      j++;
    }
    return source.substring(i + 2, j).trim();
  } else if (source[i] == '{') {
    // Block body: brace-match to find the end.
    var depth = 1;
    var j = i + 1;
    while (depth > 0) {
      if (source[j] == '{') depth++;
      if (source[j] == '}') depth--;
      j++;
    }
    return source.substring(i + 1, j - 1).trim();
  }
  fail('unexpected body form for $methodName at offset $i');
}

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    service = ChartDataService(db, profileId: profileId);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertCompletion({
    required DateTime completedAt,
    String curriculumId = 'mishnayos',
    int points = 10,
    int stageId = 1,
    String sefariaRef = 'ref_1',
    int? trackIdOverride,
  }) => seedCompletion(
    db,
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackIdOverride ?? trackId),
      eventTimestamp: completedAt,
      points: Value(points),
    ),
  );

  Future<void> insertGoal({
    String curriculumId = 'mishnayos',
    DateTime? createdAt,
    DateTime? targetDate,
    DateTime? updatedAt,
  }) {
    final now = DateTime.utc(2026, 1, 1);
    return db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackId: trackId,
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now,
            targetDate: Value(targetDate),
          ),
        );
  }

  group('ChartDataService', () {
    group('getDailyCompletions', () {
      test('returns zero-filled entries for empty range', () async {
        final start = DateTime(2026, 3, 1);
        final end = DateTime(2026, 3, 3);
        final result = await service.getDailyCompletions(
          startDate: start,
          endDate: end,
        );

        expect(result, hasLength(3));
        expect(result.every((d) => d.count == 0), isTrue);
      });

      test('counts completions per day', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 3, 8),
          sefariaRef: 'ref_3',
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(3));
        expect(result[0].count, 2); // March 1
        expect(result[1].count, 0); // March 2
        expect(result[2].count, 1); // March 3
      });

      test('filters by curriculumId when provided', () async {
        // Bavli track for the same profile.
        final bavliTrack = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          curriculumId: 'bavli',
          trackIdOverride: bavliTrack,
        );
        // A mishnayos completion on the same day must NOT count.
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 12),
          curriculumId: 'mishnayos',
          sefariaRef: 'mish_ref',
        );

        final result = await service.getDailyCompletions(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          curriculumId: 'bavli',
        );

        expect(result, hasLength(1));
        expect(result[0].count, 1);
      });
    });

    group('getCumulativeProgress', () {
      test('returns monotonically increasing totals', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 2, 10),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 2, 14),
          sefariaRef: 'ref_3',
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(3));
        expect(result[0].total, 1);
        expect(result[1].total, 3);
        expect(result[2].total, 3);
      });

      test('includes completions before start date in baseline', () async {
        await insertCompletion(completedAt: DateTime(2026, 2, 28, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          sefariaRef: 'ref_2',
        );

        final result = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
        );

        expect(result, hasLength(1));
        expect(result[0].total, 2); // 1 before + 1 on day
      });
    });

    group('getDailyPoints', () {
      test('returns null for adult mode', () async {
        final result = await service.getDailyPoints(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          userMode: ProfileMode.adult,
        );

        expect(result, isNull);
      });

      test('returns points per day for child mode', () async {
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 10),
          points: 5,
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          points: 3,
          sefariaRef: 'ref_2',
        );

        final result = await service.getDailyPoints(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 1),
          userMode: ProfileMode.child,
        );

        expect(result, isNotNull);
        expect(result, hasLength(1));
        expect(result![0].points, 8);
      });
    });

    group('getStreakCalendar', () {
      test('returns set of active dates', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 1, 14),
          sefariaRef: 'ref_2',
        );
        await insertCompletion(
          completedAt: DateTime(2026, 3, 3, 8),
          sefariaRef: 'ref_3',
        );

        final result = await service.getStreakCalendar(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(result, hasLength(2)); // March 1 and March 3
        expect(result.contains(DateTime(2026, 3, 1)), isTrue);
        expect(result.contains(DateTime(2026, 3, 3)), isTrue);
      });
    });

    // Consolidated from chart_data_service_extended_test.dart +
    // chart_data_service_extra_test.dart (AUD-t-progress-03): both files
    // independently reimplemented the same getTargetLine coverage with
    // their own setUp/insertGoal copies (Fowler duplication / AG-5 — one
    // mirrored test suite per source file). extra_test.dart's one
    // genuinely unique case (baselineCount excludes pre-goal completions)
    // is folded in below; both source files are deleted.
    group('getTargetLine', () {
      test('returns null when no goals for curriculum', () async {
        final result = await service.getTargetLine(
          curriculumId: 'mishnayos',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 14),
        );
        expect(result, isNull);
      });

      test('returns null when goal has no targetDate', () async {
        await insertGoal(curriculumId: 'mishnayos', targetDate: null);

        final result = await service.getTargetLine(
          curriculumId: 'mishnayos',
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 14),
        );
        expect(result, isNull);
      });

      test(
        'returns null when goal targetDate is same as createdAt (0 days)',
        () async {
          final d = DateTime.utc(2026, 5, 14);
          await insertGoal(
            curriculumId: 'mishnayos',
            createdAt: d,
            targetDate: d, // totalDays == 0 → null
          );

          final result = await service.getTargetLine(
            curriculumId: 'mishnayos',
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 14),
          );
          expect(result, isNull);
        },
      );

      test(
        'returns target line points when goal and targetDate are set',
        () async {
          final goalCreatedAt = DateTime.utc(2026, 5, 1);
          final goalTargetDate = DateTime.utc(2026, 5, 31);

          await insertGoal(
            curriculumId: 'mishnayos',
            createdAt: goalCreatedAt,
            targetDate: goalTargetDate,
          );
          await insertCompletion(
            curriculumId: 'mishnayos',
            completedAt: DateTime.utc(2026, 5, 10),
          );

          final result = await service.getTargetLine(
            curriculumId: 'mishnayos',
            startDate: DateTime(2026, 5, 5),
            endDate: DateTime(2026, 5, 10),
          );

          expect(result, isNotNull);
          expect(result!.isNotEmpty, isTrue);
          // Should have one entry per day: May 5–10 = 6 days.
          expect(result.length, 6);
        },
      );

      test(
        'target line is monotonically non-decreasing within range',
        () async {
          final goalCreated = DateTime.utc(2026, 1, 1);
          final goalTarget = DateTime.utc(2026, 12, 31);

          await insertGoal(
            curriculumId: 'mishnayos',
            createdAt: goalCreated,
            targetDate: goalTarget,
          );
          for (var i = 1; i <= 10; i++) {
            await insertCompletion(
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 1:$i',
              completedAt: DateTime.utc(2026, 5, i),
            );
          }

          final result = await service.getTargetLine(
            curriculumId: 'mishnayos',
            startDate: DateTime(2026, 5, 1),
            endDate: DateTime(2026, 5, 10),
          );

          expect(result, isNotNull);
          for (var i = 1; i < result!.length; i++) {
            expect(
              result[i].expectedTotal,
              greaterThanOrEqualTo(result[i - 1].expectedTotal),
            );
          }
        },
      );

      // Unique case from chart_data_service_extra_test.dart — not
      // reimplemented by extended_test.dart.
      test(
        'baselineCount excludes completions before goal.createdAt',
        () async {
          // Insert 3 completions before the goal was created.
          for (var i = 1; i <= 3; i++) {
            await insertCompletion(
              curriculumId: 'mishnayos',
              sefariaRef: 'pre_goal_$i',
              completedAt: DateTime.utc(2025, 12, i),
            );
          }

          final goalCreated = DateTime.utc(2026, 1, 1);
          final goalEnd = DateTime.utc(2026, 1, 11);
          await insertGoal(
            curriculumId: 'mishnayos',
            createdAt: goalCreated,
            targetDate: goalEnd,
          );

          // 2 completions within the goal window.
          for (var i = 1; i <= 2; i++) {
            await insertCompletion(
              curriculumId: 'mishnayos',
              sefariaRef: 'in_window_$i',
              completedAt: DateTime.utc(2026, 1, i),
            );
          }

          final result = await service.getTargetLine(
            curriculumId: 'mishnayos',
            startDate: goalCreated,
            endDate: goalEnd,
          );

          expect(result, isNotNull);
          // First point (at start date) should reflect the baseline offset.
          // Baseline = 3 (pre-goal completions). At t=0, fraction=0, so
          // expectedTotal = baselineCount + totalCompletions * 0 = 3.
          expect(result!.first.expectedTotal, greaterThanOrEqualTo(3.0));
        },
      );
    });

    // AUD-progress-05 — getDailyCompletionsLive / getCumulativeProgressLive
    // were byte-identical duplicates of getDailyCompletions /
    // getCumulativeProgress (~140 duplicated lines, no behavioral
    // difference). getDailyCompletionsLive had zero callers (dead code) and
    // is deleted outright; getCumulativeProgressLive is still called from
    // recent_activity_providers.dart and is kept as a one-line delegate for
    // callsite stability, per the finding's recommendation.
    //
    // These are source-inspection tests (mirroring the
    // aud_core_widgets_03_no_color_literals_test.dart pattern) rather than
    // behavioral ones: nothing about the two methods' *output* was ever
    // wrong, so a black-box behavioral test can't distinguish "coincidentally
    // identical" from "duplicated logic that will silently diverge next
    // time only one twin gets touched" — the actual defect. Reading
    // `_chartDataServicePath`'s own text is the only way to assert the
    // duplication is gone.
    group('*Live methods (AUD-progress-05 — no independent duplicate logic)', () {
      late String source;

      setUp(() {
        source = File(_chartDataServicePath).readAsStringSync();
      });

      test('getDailyCompletionsLive no longer exists (was dead-code duplicate '
          'of getDailyCompletions)', () {
        expect(
          source.contains('getDailyCompletionsLive'),
          isFalse,
          reason:
              'getDailyCompletionsLive duplicated getDailyCompletions with '
              'zero callers (verified dead code) — AUD-progress-05 requires '
              'it be deleted.',
        );
      });

      test('getCumulativeProgressLive delegates to getCumulativeProgress in '
          'one line, carrying no independent query/bucketing logic', () {
        final body = _extractMethodImpl(source, 'getCumulativeProgressLive');

        expect(
          body.contains('getCumulativeProgress('),
          isTrue,
          reason:
              'getCumulativeProgressLive must delegate to '
              'getCumulativeProgress — got body:\n$body',
        );

        const independentLogicMarkers = [
          '_effectiveStartDate',
          '_bucketizeCumulative',
          '_db.completionDao',
          '_extractLocalDate',
        ];
        for (final marker in independentLogicMarkers) {
          expect(
            body.contains(marker),
            isFalse,
            reason:
                'getCumulativeProgressLive still reimplements query/bucketing '
                'logic independently (found "$marker") instead of delegating '
                '— AUD-progress-05 body:\n$body',
          );
        }
      });

      test('getCumulativeProgressLive returns the exact result of '
          'getCumulativeProgress for identical inputs (behavioral parity '
          'preserved by the delegation)', () async {
        await insertCompletion(completedAt: DateTime(2026, 3, 1, 10));
        await insertCompletion(
          completedAt: DateTime(2026, 3, 2, 10),
          sefariaRef: 'ref_2',
        );

        final direct = await service.getCumulativeProgress(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );
        final viaLive = await service.getCumulativeProgressLive(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 3),
        );

        expect(viaLive.map((p) => p.total), direct.map((p) => p.total));
        expect(viaLive.map((p) => p.date), direct.map((p) => p.date));
      });
    });
  });
}
