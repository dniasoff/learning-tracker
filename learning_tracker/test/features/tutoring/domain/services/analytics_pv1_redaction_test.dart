/// AUD-core-analytics-01 (PV-1) regression coverage for one of the seven
/// cited leak sites that live in `features/tutoring/domain/services/`:
///
///   - [TutorPinService.setTutorPin] must fire `tutor_pin_set` WITHOUT a
///     `profile_id` parameter.
///
/// The other six cited sites are covered by:
///   - test/core/sync/outbox/outbox_processor_test.dart (entity_key)
///   - test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart
///     (merge_router_halt profile_id)
///   - test/core/sync/sync_orchestrator_test.dart (pull_failed / listener_error)
///
/// A `TutorAuditLogWriter — AUD-core-analytics-01 (PV-1)` group covering
/// `tutor_action_recorded` redaction previously lived here. AUD-tutoring-06
/// deleted `TutorAuditLogWriter` (and the `tutor_action_recorded` analytics
/// call it was the sole emitter of) as confirmed-dead code: it was never
/// constructed anywhere in `lib/` — the real tutor audit trail is written
/// server-side by each `tutor*` Cloud Function via `writeAuditLog()`, which
/// never touches client-side analytics. With the emitter gone, there is no
/// production `target` leak left for this group to guard against, so it was
/// removed rather than left asserting against deleted code.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
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

void main() {
  group('TutorPinService.setTutorPin — AUD-core-analytics-01 (PV-1)', () {
    test('tutor_pin_set analytics fires without a profile_id', () async {
      final analytics = _RecordingAnalyticsService();
      final pinService = TutorPinService(
        PinService(_createInMemorySecureStorage()),
        analytics: analytics,
      );

      final result = await pinService.setTutorPin(
        profileId: '01JQ3K5M8N2P4R6T7V9X0Z1AB',
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
}
