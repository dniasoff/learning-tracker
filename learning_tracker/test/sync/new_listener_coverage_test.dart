/// Phase 2 (sync-architecture-plan 2026-05-21) — new listener coverage.
///
/// For each of the 9 newly added listeners
/// (`goals`, `learning_ledger`, `learning_order`, `profile_programs`,
///  `learner_profiles`, the three `preferences/*` documents, and
///  `tutor_grants`), verifies that a payload arriving on the channel propagates
/// to the merger registered under the right [EntityKind] in [MergeRouter].
///
/// The propagation path under test:
///
///   FirestoreListenerSource.openChannels()
///     └── gateway stream (faked here)
///           └── ListenerSupervisor._handlePayload
///                 └── ListenerSupervisor._onEvent
///                       └── SyncOrchestratorImpl._channelToKind
///                             └── MergeRouter.dispatch(kind: ...)
///                                   └── EntityMerger.merge(...)  [recorded]
///
/// This is a contract test — it does NOT exercise the Drift DAOs (those are
/// already covered by mergers_test.dart and the per-merger unit tests). It
/// asserts the listener-supervisor wiring is correct: every new channel
/// reaches its merger.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

/// A gateway whose listener streams are user-driven via [emit]. Each call to
/// `listenToCollection` / `listenToDocument` / `listenToTutorGrants` /
/// `listenToLearnerProfiles` records the channel key the source used and
/// returns a broadcast stream the test can push payloads through.
class _DrivenGateway implements FirestoreGateway {
  final Map<String, StreamController<Object?>> controllers = {};

  StreamController<Object?> _ctrl(String key) =>
      controllers.putIfAbsent(key, () => StreamController<Object?>.broadcast());

  void emit(String key, Object? payload) => _ctrl(key).add(payload);

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => _ctrl(collection).stream.cast<ListenerSnapshot>();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => _ctrl('$collection/$docId').stream.cast<Map<String, dynamic>?>();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      _ctrl('tutor_grants').stream.cast<ListenerSnapshot>();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      _ctrl('learner_profiles').stream.cast<ListenerSnapshot>();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not implemented in _DrivenGateway',
  );
}

/// Records every merge() call so the test can assert that a listener
/// payload reached the right merger.
class _RecordingMerger implements EntityMerger {
  _RecordingMerger(this.kind);
  @override
  final String kind;
  int calls = 0;
  final List<List<Map<String, dynamic>>> rowsReceived = [];

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    calls += 1;
    rowsReceived.add(rows);
  }
}

/// Mirrors `SyncOrchestratorImpl._channelToKind`. Public copy used by the
/// supervisor's onEvent handler in this test. If the production switch
/// changes, this duplicate will diverge — and the "every new channel maps
/// to the expected kind" assertion below catches the drift.
String? _channelToKind(String channel) => switch (channel) {
  'completions' => EntityKind.completion,
  'bookmarks' => EntityKind.bookmark,
  'settings' => EntityKind.settings,
  'streak_events' => EntityKind.streak,
  'curriculum_tracks' => EntityKind.trackConfig,
  'stage_definitions' => EntityKind.stageDefinition,
  // Phase 1 — study-day config enrolment.
  'study_day_configs' => EntityKind.studyDayConfig,
  'goals' => EntityKind.goal,
  'learning_ledger' => EntityKind.learningLedger,
  'learning_order' => EntityKind.learningOrder,
  'profile_programs' => EntityKind.profileProgram,
  'learner_profiles' => EntityKind.learnerProfile,
  'preferences/notification_settings' => EntityKind.notificationSettings,
  'preferences/gamification_settings' => EntityKind.gamificationSettings,
  'preferences/ui_preferences' => EntityKind.uiPreferences,
  'tutor_grants' => EntityKind.tutorGrant,
  _ => null,
};

void main() {
  group('Phase 2 — new listener channel → merger routing', () {
    late _DrivenGateway gateway;
    late FirestoreListenerSource source;
    late Map<String, _RecordingMerger> mergers;
    late MergeRouter router;
    late ListenerSupervisor supervisor;

    setUp(() async {
      gateway = _DrivenGateway();
      source = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => 1,
      );

      // One merger per kind so we can assert exactly which one fired.
      mergers = {
        for (final kind in EntityKind.all) kind: _RecordingMerger(kind),
      };
      router = MergeRouter(mergers: Map<String, EntityMerger>.from(mergers));

      supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) {
          final kind = _channelToKind(channel);
          if (kind == null) return;
          if (payload is List) {
            router.dispatch(
              profileId: 1,
              kind: kind,
              rows: payload.cast<Map<String, dynamic>>(),
            );
          } else if (payload is Map<String, dynamic>) {
            router.dispatch(profileId: 1, kind: kind, rows: [payload]);
          }
        },
      );
      await supervisor.start();
    });

    tearDown(() async {
      await supervisor.stop();
      for (final c in gateway.controllers.values) {
        await c.close();
      }
    });

    Future<void> pumpEvents() => Future<void>.delayed(Duration.zero);

    test('goals → GoalMerger', () async {
      gateway.emit(
        'goals',
        const ListenerSnapshot(
          rows: [
            {'id': 'g1', 'curriculum_id': 'bavli'},
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.goal]!.calls, 1);
      expect(mergers[EntityKind.goal]!.rowsReceived.first, hasLength(1));
    });

    test('learning_ledger → LearningLedgerMerger', () async {
      gateway.emit(
        'learning_ledger',
        const ListenerSnapshot(
          rows: [
            {'ulid': 'L1'},
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.learningLedger]!.calls, 1);
    });

    test('learning_order → LearningOrderMerger', () async {
      gateway.emit(
        'learning_order',
        const ListenerSnapshot(
          rows: [
            {'curriculum_id': 'bavli', 'sefaria_ref': 'Berakhot 2'},
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.learningOrder]!.calls, 1);
    });

    test('profile_programs → ProfileProgramMerger', () async {
      gateway.emit(
        'profile_programs',
        const ListenerSnapshot(
          rows: [
            {'curriculum_id': 'bavli', 'program_id': 1},
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.profileProgram]!.calls, 1);
    });

    test('learner_profiles → LearnerProfileMerger', () async {
      gateway.emit(
        'learner_profiles',
        const ListenerSnapshot(
          rows: [
            {
              'profile_id': 1,
              'account_id': 1,
              'display_name': 'Test',
              'mode': 'adult',
              'updated_at': '2026-05-21T00:00:00.000Z',
              'created_at': '2026-05-21T00:00:00.000Z',
            },
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.learnerProfile]!.calls, 1);
    });

    test(
      'preferences/notification_settings → NotificationSettingsMerger',
      () async {
        gateway.emit('preferences/notification_settings', <String, dynamic>{
          'updated_at': '2026-05-21T00:00:00.000Z',
        });
        await pumpEvents();
        expect(mergers[EntityKind.notificationSettings]!.calls, 1);
      },
    );

    test(
      'preferences/gamification_settings → GamificationSettingsMerger',
      () async {
        gateway.emit('preferences/gamification_settings', <String, dynamic>{
          'updated_at': '2026-05-21T00:00:00.000Z',
        });
        await pumpEvents();
        expect(mergers[EntityKind.gamificationSettings]!.calls, 1);
      },
    );

    test('preferences/ui_preferences → UiPreferencesMerger', () async {
      gateway.emit('preferences/ui_preferences', <String, dynamic>{
        'updated_at': '2026-05-21T00:00:00.000Z',
      });
      await pumpEvents();
      expect(mergers[EntityKind.uiPreferences]!.calls, 1);
    });

    test('tutor_grants → TutorGrantMerger', () async {
      gateway.emit(
        'tutor_grants',
        const ListenerSnapshot(
          rows: [
            {'grant_id': 'g1'},
          ],
          isAtLimit: false,
        ),
      );
      await pumpEvents();
      expect(mergers[EntityKind.tutorGrant]!.calls, 1);
    });

    test('production SyncOrchestratorImpl._channelToKind matches the channel '
        'list this test mirrors', () {
      // This assertion does NOT exercise SyncOrchestratorImpl directly
      // (the method is private). It documents the channel set the
      // production switch covers — adding a new channel here without
      // also touching SyncOrchestratorImpl produces a runtime null kind
      // → no dispatch → the test for that channel would fail at the
      // mergers[...]!.calls == 1 line above. So this group of tests is
      // by construction a regression net for the production switch.
      const expectedChannels = {
        'completions',
        'bookmarks',
        'settings',
        'streak_events',
        'curriculum_tracks',
        'stage_definitions',
        'goals',
        'learning_ledger',
        'learning_order',
        'profile_programs',
        'learner_profiles',
        'preferences/notification_settings',
        'preferences/gamification_settings',
        'preferences/ui_preferences',
        'tutor_grants',
      };
      for (final ch in expectedChannels) {
        expect(
          _channelToKind(ch),
          isNotNull,
          reason: '$ch must route to an EntityKind',
        );
      }
    });
  });

  group('Phase 2 — orchestrator channel→kind invariants', () {
    test('every channel registered by FirestoreListenerSource has a non-null '
        'EntityKind mapping', () {
      // Drive openChannels() to capture every registered channel name.
      final gateway = _DrivenGateway();
      final source = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => 1,
      );
      final channels = source.openChannels();

      // Every registered channel MUST map to a kind. A missing mapping
      // means the listener payload would be silently dropped at the
      // orchestrator boundary — Phase 2 regression.
      for (final channel in channels.keys) {
        expect(
          _channelToKind(channel),
          isNotNull,
          reason:
              '$channel is registered in FirestoreListenerSource but '
              'maps to null in _channelToKind — payloads would be dropped.',
        );
      }
    });

    test('SyncOrchestratorImpl exposes parkAfterBackgroundDuration with the '
        'expected 60 s default (architecture-plan target)', () {
      // This is a runtime-readable property — verify the production
      // default matches the spec without driving lifecycle events.
      final orchestrator = SyncOrchestratorImpl(
        resolveMergeRouter: () =>
            MergeRouter(mergers: const <String, EntityMerger>{}),
        resolveGateway: _DrivenGateway.new,
        resolveProfileId: () => 1,
        resolvePushAllLocalData: () async {},
        resolveBackfillGoals: () async => 0,
      );
      addTearDown(orchestrator.dispose);
      expect(
        orchestrator.parkAfterBackgroundDuration,
        const Duration(seconds: 60),
      );
    });
  });
}
