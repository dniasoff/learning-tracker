/// Mandatory-pace invariant tests (Wave 4-C).
///
/// Architecture §10.3: a self-paced track MUST have an explicit pace.  The
/// setup UI is the chokepoint that enforces this — every code path that
/// creates a self-paced track produces a goal with `paceValue != null` and
/// `pacePeriod != null`.  Tests:
///   P1 — `derivePaceFromDeadline` (the helper used by deadline-mode setup)
///        always returns a positive paceValue and non-empty pacePeriod.
///   P2 — `derivePaceFromDeadline` returns the expected per-week pace for a
///        typical scope+window combination.
///   P3 — `derivePaceFromDeadline` falls back to (1, per_week) when the
///        window or scope is empty so the invariant holds in edge cases.
///   P4 — Projection invariant: `selfPacedSchedule(pace: null, ...)` throws
///        `MissingPaceError` — the projection's API guarantees that
///        paceless tracks cannot quietly render zero.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/goal_helpers.dart';

/// Builds a simple study-day map with [n] study days per week (Mon–Sun order).
Map<int, String> _studyDays(int n) {
  assert(n >= 0 && n <= 7);
  final map = <int, String>{};
  for (var i = 1; i <= 7; i++) {
    map[i] = i <= n ? 'study' : 'rest';
  }
  return map;
}

void main() {
  // ── P1 ── derivePaceFromDeadline: invariant — always emits a pace ────────
  group('P1: derivePaceFromDeadline — deadline mode always emits a pace', () {
    test(
      'typical 7-day window, 120 items, 5 study days/week → positive pace',
      () {
        final result = derivePaceFromDeadline(
          studyDays: _studyDays(5),
          totalScopeItems: 120,
          studyDaysInWindow: 7,
        );
        expect(
          result.paceValue,
          greaterThan(0),
          reason: 'P1: paceValue must be positive',
        );
        expect(
          result.pacePeriod,
          isNotEmpty,
          reason: 'P1: pacePeriod must be non-empty',
        );
      },
    );

    test('result paceValue is never zero or negative — invariant §10.3', () {
      final result = derivePaceFromDeadline(
        studyDays: _studyDays(7),
        totalScopeItems: 360,
        studyDaysInWindow: 90,
      );
      expect(
        result.paceValue,
        greaterThan(0),
        reason: 'P1: paceValue is never zero or negative',
      );
      expect(
        result.pacePeriod,
        isNotEmpty,
        reason: 'P1: pacePeriod is never empty',
      );
    });
  });

  // ── P2 ── derivePaceFromDeadline: typical inputs ─────────────────────────
  group('P2: derivePaceFromDeadline — math matches the displayed estimate', () {
    test('100 items, 10 study-day window, 5 study-days/week → 50/week', () {
      final result = derivePaceFromDeadline(
        studyDays: _studyDays(5),
        totalScopeItems: 100,
        studyDaysInWindow: 10,
      );
      // ceil(100/10) = 10 items/day. 10 * 5 = 50/week.
      expect(result.paceValue, 50);
      expect(result.pacePeriod, 'per_week');
    });

    test('30 items, 14 study-day window, 6 study-days/week → 18/week', () {
      final result = derivePaceFromDeadline(
        studyDays: _studyDays(6),
        totalScopeItems: 30,
        studyDaysInWindow: 14,
      );
      // ceil(30/14) = 3 items/study-day. 3 * 6 = 18/week.
      expect(result.paceValue, 18);
      expect(result.pacePeriod, 'per_week');
    });
  });

  // ── P3 ── derivePaceFromDeadline: edge-case fallback ─────────────────────
  group(
    'P3: derivePaceFromDeadline — fallback when window or scope is empty',
    () {
      test('studyDaysInWindow == 0 → (1, per_week)', () {
        final result = derivePaceFromDeadline(
          studyDays: _studyDays(5),
          totalScopeItems: 120,
          studyDaysInWindow: 0,
        );
        expect(
          result.paceValue,
          1,
          reason: 'P3: fallback pace is 1 when the window is empty',
        );
        expect(result.pacePeriod, 'per_week');
      });

      test('totalScopeItems == 0 → (1, per_week)', () {
        final result = derivePaceFromDeadline(
          studyDays: _studyDays(5),
          totalScopeItems: 0,
          studyDaysInWindow: 14,
        );
        expect(result.paceValue, 1, reason: 'P3: fallback when scope is empty');
        expect(result.pacePeriod, 'per_week');
      });
    },
  );

  // ── P4 ── Projection API: null pace is a hard error ──────────────────────
  //
  // The pure projection enforces the invariant the setup UI is built to
  // satisfy.  A caller cannot accidentally pass a null pace and get an
  // empty-but-silent result — it raises MissingPaceError.
  group('P4: selfPacedSchedule rejects null pace with MissingPaceError', () {
    test('null pace → MissingPaceError', () {
      final today = DateTime.utc(2026, 5, 19);
      final anchor = today.subtract(const Duration(days: 7));
      expect(
        () => selfPacedSchedule(
          anchor: anchor,
          pace: null,
          studyDayPattern: const StudyDayPattern({
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          }),
          orderedRefs: List.generate(30, (i) => 'Mishnayos $i'),
          today: today,
        ),
        throwsA(isA<MissingPaceError>()),
        reason:
            'P4: the projection rejects a null pace — the setup UI is the '
            'single chokepoint that guarantees a pace exists.',
      );
    });
  });
}
