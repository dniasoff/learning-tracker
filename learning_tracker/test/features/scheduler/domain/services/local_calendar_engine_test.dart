/// Regression tests for LocalCalendarEngine — R4-1 timezone fix.
///
/// Before the fix, _parseDateKey returned DateTime(year, month, day) — a
/// local-timezone midnight.  The projection helpers (e.g. _dayOnly in
/// overdue_schedule.dart) then do DateTime.utc(dt.year, dt.month, dt.day),
/// which extracts the UTC components of a local midnight, shifting the
/// effective calendar date by the device's UTC offset.  For Israel (UTC+3)
/// this means May 31 local is 2026-05-30T21:00Z → _dayOnly yields May 30 UTC.
///
/// The fix: _parseDateKey now returns DateTime.utc(year, month, day) so the
/// parsed date is already UTC-midnight and flows safely into projection code.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';

import '../../../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seed a single CalendarCycles row into [db].
Future<void> _seedRow(
  ContentDatabase db, {
  required String programKey,
  required String dateKey,
  required String sefariaRef,
}) async {
  await db
      .into(db.calendarCycles)
      .insert(
        CalendarCyclesCompanion.insert(
          programKey: programKey,
          dateKey: dateKey,
          sefariaRef: sefariaRef,
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late ContentDatabase db;
  late LocalCalendarEngine engine;

  // Use a well-known program that is registered in CalendarProgramRegistry.
  // 'daf_yomi' is the canonical ID for Daf Yomi (registry key = 'daf_yomi').
  final programId =
      CalendarProgramRegistry.programs.first.id; // stable first entry

  setUp(() {
    db = createTestContentDatabase();
    engine = LocalCalendarEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── R4-1 regression: _parseDateKey must return UTC-midnight ─────────────

  group('R4-1: getEntry — parsed date is UTC midnight', () {
    test('entry.date.isUtc is true for a YYYY-MM-DD key', () async {
      await _seedRow(
        db,
        programKey: programId,
        dateKey: '2026-05-31',
        sefariaRef: 'Hullin 25a',
      );

      final entry = await engine.getEntry(programId, DateTime.utc(2026, 5, 31));

      expect(entry, isNotNull);
      expect(
        entry!.date!.isUtc,
        isTrue,
        reason:
            '_parseDateKey must return DateTime.utc so projection helpers '
            '(which do DateTime.utc(dt.year, dt.month, dt.day)) do not '
            'shift the calendar date by the device UTC offset (R4-1).',
      );
    });

    test('entry.date components match the YYYY-MM-DD key exactly', () async {
      await _seedRow(
        db,
        programKey: programId,
        dateKey: '2026-05-31',
        sefariaRef: 'Hullin 25a',
      );

      final entry = await engine.getEntry(programId, DateTime.utc(2026, 5, 31));

      expect(entry!.date!.year, 2026);
      expect(entry.date!.month, 5);
      expect(entry.date!.day, 31);
    });

    test('entry.date is midnight (hour/minute/second all zero)', () async {
      await _seedRow(
        db,
        programKey: programId,
        dateKey: '2026-01-01',
        sefariaRef: 'Some ref',
      );

      final entry = await engine.getEntry(programId, DateTime.utc(2026, 1, 1));

      expect(entry!.date!.hour, 0);
      expect(entry.date!.minute, 0);
      expect(entry.date!.second, 0);
      expect(entry.date!.millisecond, 0);
    });
  });

  group('R4-1: getEntriesForRange — all parsed dates are UTC midnight', () {
    test('every entry in a multi-day range has isUtc == true', () async {
      final keys = ['2026-05-29', '2026-05-30', '2026-05-31'];
      for (final (i, k) in keys.indexed) {
        await _seedRow(
          db,
          programKey: programId,
          dateKey: k,
          sefariaRef: 'Ref $i',
        );
      }

      final entries = await engine.getEntriesForRange(
        programId,
        DateTime.utc(2026, 5, 29),
        DateTime.utc(2026, 5, 31),
      );

      expect(entries.length, 3);
      for (final entry in entries) {
        expect(
          entry.date!.isUtc,
          isTrue,
          reason: 'Entry date for key ${entry.todayRef} must be UTC midnight.',
        );
      }
    });

    test('entry dates have the exact y/m/d from their DB key', () async {
      final data = [
        ('2026-05-29', 2026, 5, 29),
        ('2026-05-30', 2026, 5, 30),
        ('2026-05-31', 2026, 5, 31),
      ];
      for (final (i, (k, _, _, _)) in data.indexed) {
        await _seedRow(
          db,
          programKey: programId,
          dateKey: k,
          sefariaRef: 'Ref $i',
        );
      }

      final entries = await engine.getEntriesForRange(
        programId,
        DateTime.utc(2026, 5, 29),
        DateTime.utc(2026, 5, 31),
      );

      expect(entries.length, data.length);
      for (final (i, entry) in entries.indexed) {
        final (_, ey, em, ed) = data[i];
        expect(entry.date!.year, ey, reason: 'Year mismatch at index $i');
        expect(entry.date!.month, em, reason: 'Month mismatch at index $i');
        expect(entry.date!.day, ed, reason: 'Day mismatch at index $i');
      }
    });
  });

  group('R4-1: getTodayPrograms — parsed date is UTC midnight', () {
    test('entry.date.isUtc is true', () async {
      await _seedRow(
        db,
        programKey: programId,
        dateKey: '2026-05-31',
        sefariaRef: 'Hullin 25a',
      );

      // getTodayPrograms takes an optional DateTime for the lookup date.
      final entries = await engine.getTodayPrograms(DateTime.utc(2026, 5, 31));

      expect(entries, isNotEmpty);
      for (final entry in entries) {
        if (entry.programId == programId) {
          expect(entry.date!.isUtc, isTrue);
          expect(entry.date!.year, 2026);
          expect(entry.date!.month, 5);
          expect(entry.date!.day, 31);
        }
      }
    });
  });
}
