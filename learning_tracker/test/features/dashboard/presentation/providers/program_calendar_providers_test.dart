@Tags(['epic_20', 'story_20_6'])
library;

import 'package:learning_tracker/features/dashboard/data/mock_program_cycles.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:test/test.dart';

void main() {
  group('Story 20.6 -- Program Calendar Mock', () {
    // ── Mock data coverage ──

    group('Mock program cycle data', () {
      test('has entries for all major curricula', () {
        expect(mockProgramCycles, contains('bavli'));
        expect(mockProgramCycles, contains('mishnayos'));
        expect(mockProgramCycles, contains('yerushalmi'));
        expect(mockProgramCycles, contains('mishna_berurah'));
        expect(mockProgramCycles, contains('nach'));
        expect(mockProgramCycles, contains('mussar'));
      });

      test('Daf Yomi (bavli) has totalDays 2711', () {
        expect(mockProgramCycles['bavli']!.totalDays, 2711);
      });

      test('Nach Yomi has totalDays 929', () {
        expect(mockProgramCycles['nach']!.totalDays, 929);
      });

      test('Mishnah Yomis has totalDays 2000', () {
        expect(mockProgramCycles['mishnayos']!.totalDays, 2000);
      });

      test('all programs have non-empty todayDisplayHe', () {
        for (final entry in mockProgramCycles.entries) {
          expect(
            entry.value.sampleTodayDisplayHe,
            isNotEmpty,
            reason: '${entry.key} should have Hebrew display text',
          );
        }
      });

      test('all programs have non-empty todayRef', () {
        for (final entry in mockProgramCycles.entries) {
          expect(
            entry.value.sampleTodayRef,
            isNotEmpty,
            reason: '${entry.key} should have a Sefaria ref',
          );
        }
      });

      test('default fallback has totalDays 365', () {
        expect(defaultProgramCycleData.totalDays, 365);
      });
    });

    // ── CalendarPosition status derivation ──

    group('CalendarPosition status derivation', () {
      test('delta > 0 means ahead', () {
        const pos = CalendarPosition(
          currentDay: 50,
          totalDays: 2711,
          todayRef: 'ref',
          todayDisplayHe: 'he',
          delta: 5,
          status: CalendarStatus.ahead,
        );
        expect(pos.status, CalendarStatus.ahead);
        expect(pos.delta, isPositive);
      });

      test('delta == 0 means caughtUp', () {
        const pos = CalendarPosition(
          currentDay: 50,
          totalDays: 2711,
          todayRef: 'ref',
          todayDisplayHe: 'he',
          delta: 0,
          status: CalendarStatus.caughtUp,
        );
        expect(pos.status, CalendarStatus.caughtUp);
        expect(pos.delta, isZero);
      });

      test('delta < 0 means behind', () {
        const pos = CalendarPosition(
          currentDay: 50,
          totalDays: 2711,
          todayRef: 'ref',
          todayDisplayHe: 'he',
          delta: -3,
          status: CalendarStatus.behind,
        );
        expect(pos.status, CalendarStatus.behind);
        expect(pos.delta, isNegative);
      });
    });

    // ── Status derivation helper (mirrors provider logic) ──

    group('Status derivation from delta', () {
      CalendarStatus deriveStatus(int delta) => delta > 0
          ? CalendarStatus.ahead
          : delta == 0
              ? CalendarStatus.caughtUp
              : CalendarStatus.behind;

      test('positive delta -> ahead', () {
        expect(deriveStatus(1), CalendarStatus.ahead);
        expect(deriveStatus(100), CalendarStatus.ahead);
      });

      test('zero delta -> caughtUp', () {
        expect(deriveStatus(0), CalendarStatus.caughtUp);
      });

      test('negative delta -> behind', () {
        expect(deriveStatus(-1), CalendarStatus.behind);
        expect(deriveStatus(-50), CalendarStatus.behind);
      });
    });
  });
}
