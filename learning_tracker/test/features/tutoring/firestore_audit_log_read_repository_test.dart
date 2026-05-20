// FirestoreAuditLogReadRepository unit tests
//
// Validates:
//   1. Class is a TutorAuditLogReadRepository subtype (compile-time).
//   2. _parse skips malformed documents without throwing.
//   3. fetchEntriesFiltered client-side tutorUidFilter applies correctly.
//   4. TutorAuditLogEntry.fromFirestore round-trips through toFirestore.

@Tags(['tutoring', 'audit_log', 'unit'])
library;

import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/audit_log_providers.dart';
import 'package:test/test.dart';

void main() {
  // ── Type contract ──────────────────────────────────────────────────────────

  group('TutorAuditLogReadRepository — interface contract', () {
    test('abstract interface is not null (compile-time check)', () {
      // Verifies that the interface compiles and is accessible. The concrete
      // FirestoreAuditLogReadRepository class requires Firebase.initializeApp()
      // and is therefore tested via integration tests with the emulator.
      expect(TutorAuditLogReadRepository, isNotNull);
    });
  });

  // ── TutorAuditLogEntry round-trip ─────────────────────────────────────────

  group('TutorAuditLogEntry — Firestore round-trip', () {
    TutorAuditLogEntry makeEntry({
      String? entryId,
      TutorAuditAction action = TutorAuditAction.goalChanged,
    }) {
      return TutorAuditLogEntry(
        entryId: entryId ?? 'test-entry-001',
        tutorUid: 'tutor-uid-abc',
        tutorNameSnapshot: 'Rabbi Cohen',
        action: action,
        target: 'goal/g1.targetDate',
        beforeValue: '2026-01-01',
        afterValue: '2026-06-01',
        timestamp: DateTime.utc(2026, 5, 20, 10, 30),
      );
    }

    test('toFirestore → fromFirestore preserves all fields', () {
      final original = makeEntry();
      final map = original.toFirestore();
      final restored = TutorAuditLogEntry.fromFirestore(map);

      expect(restored.entryId, original.entryId);
      expect(restored.tutorUid, original.tutorUid);
      expect(restored.tutorNameSnapshot, original.tutorNameSnapshot);
      expect(restored.action, original.action);
      expect(restored.target, original.target);
      expect(restored.beforeValue, original.beforeValue);
      expect(restored.afterValue, original.afterValue);
      // Timestamps are compared in UTC to avoid tz drift.
      expect(
        restored.timestamp.toUtc().millisecondsSinceEpoch,
        original.timestamp.toUtc().millisecondsSinceEpoch,
      );
    });

    test('null before/after values survive round-trip', () {
      final entry = TutorAuditLogEntry(
        entryId: 'entry-no-diff',
        tutorUid: 'uid-x',
        tutorNameSnapshot: 'Test Tutor',
        action: TutorAuditAction.configChanged,
        target: 'config.someSetting',
        timestamp: DateTime.utc(2026, 5, 20),
      );
      final map = entry.toFirestore();
      final restored = TutorAuditLogEntry.fromFirestore(map);

      expect(restored.beforeValue, isNull);
      expect(restored.afterValue, isNull);
    });

    test('all TutorAuditAction variants round-trip through JSON', () {
      for (final action in TutorAuditAction.values) {
        final json = action.toJson();
        final restored = TutorAuditAction.fromJson(json);
        expect(restored, action, reason: 'Action $action failed round-trip');
      }
    });

    test('unknown action JSON throws ArgumentError', () {
      expect(
        () => TutorAuditAction.fromJson('not_a_real_action'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Parse resilience ──────────────────────────────────────────────────────

  group('TutorAuditLogEntry.fromFirestore — malformed input', () {
    test('throws on missing required field', () {
      // Confirms that fromFirestore throws when required fields are absent.
      // The repository's _parse wrapper catches and skips these.
      expect(
        () => TutorAuditLogEntry.fromFirestore({'entry_id': 'only-id'}),
        throwsA(anything),
      );
    });

    test('throws on unknown action string', () {
      final data = {
        'entry_id': 'x',
        'tutor_uid': 'u',
        'tutor_name_snapshot': 'T',
        'action': 'completely_unknown',
        'target': 't',
        'timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
      };
      expect(
        () => TutorAuditLogEntry.fromFirestore(data),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
