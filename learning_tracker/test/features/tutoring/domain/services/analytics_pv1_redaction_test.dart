/// AUD-core-analytics-01 (PV-1) regression coverage for two of the seven
/// cited leak sites that live in `features/tutoring/domain/services/`:
///
///   - [TutorPinService.setTutorPin] must fire `tutor_pin_set` WITHOUT a
///     `profile_id` parameter.
///   - [TutorAuditLogWriter] must fire `tutor_action_recorded` WITHOUT a
///     `target` parameter (its own documented shape is a resource path like
///     "profile/42.displayName" — a per-child identifier).
///
/// The other five cited sites are covered by:
///   - test/core/sync/outbox/outbox_processor_test.dart (entity_key)
///   - test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart
///     (merge_router_halt profile_id)
///   - test/core/sync/sync_orchestrator_test.dart (pull_failed / listener_error)
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_audit_log_writer.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:mocktail/mocktail.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────

class _RecordedAnalyticsEvent {
  const _RecordedAnalyticsEvent(this.name, this.parameters);
  final String name;
  final Map<String, Object?>? parameters;
}

class _RecordingAnalyticsService extends AnalyticsService {
  final List<_RecordedAnalyticsEvent> events = [];

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    events.add(_RecordedAnalyticsEvent(name, parameters));
  }
}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// In-memory secure-storage stub keyed by string (mirrors the pattern used
/// throughout the profiles/tutoring test suites).
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

class _FakeAuditLogRepository implements TutorAuditLogRepository {
  final List<TutorAuditLogEntry> entries = [];

  @override
  Future<void> appendEntry(TutorAuditLogEntry entry) async {
    entries.add(entry);
  }
}

void main() {
  group('TutorPinService.setTutorPin — AUD-core-analytics-01 (PV-1)', () {
    test('tutor_pin_set analytics fires without a profile_id', () async {
      final analytics = _RecordingAnalyticsService();
      final pinService = TutorPinService(
        PinService(_createInMemorySecureStorage()),
        analytics: analytics,
      );

      final result = await pinService.setTutorPin(
        profileId: 42,
        rawPin: '1234',
      );

      expect(result, isA<TutorPinSuccess>());
      final pinSetEvents = analytics.events.where(
        (e) => e.name == AnalyticsEvent.tutorPinSet,
      );
      expect(pinSetEvents, isNotEmpty);
      expect(
        pinSetEvents.first.parameters?.containsKey('profile_id') ?? false,
        isFalse,
        reason:
            'profile_id is a per-child identifier and must never reach an '
            'uncatalogued analytics event',
      );
    });
  });

  group('TutorAuditLogWriter — AUD-core-analytics-01 (PV-1)', () {
    test('tutor_action_recorded analytics fires without a target', () async {
      final analytics = _RecordingAnalyticsService();
      final repository = _FakeAuditLogRepository();
      final writer = TutorAuditLogWriter(
        tutorUid: 'tutor-1',
        tutorNameSnapshot: 'Tutor One',
        grantId: 'grant-1',
        repository: repository,
        analytics: analytics,
      );

      await writer.logProfileEdited(
        target: 'profile/42.displayName',
        beforeValue: 'Old Name',
        afterValue: 'New Name',
      );

      final actionEvents = analytics.events.where(
        (e) => e.name == AnalyticsEvent.tutorActionRecorded,
      );
      expect(actionEvents, isNotEmpty);
      final params = actionEvents.first.parameters;
      expect(
        params?.containsKey('target'),
        isFalse,
        reason:
            'target is documented as a resource path like '
            '"profile/42.displayName" — a per-child identifier attached to '
            'a description of what was changed — and must never reach an '
            'uncatalogued analytics event',
      );
      // The underlying audit log entry (a separate, access-controlled
      // Firestore write, not an analytics event) still carries the target —
      // only the analytics payload is redacted.
      expect(repository.entries.single.target, 'profile/42.displayName');
    });
  });
}
