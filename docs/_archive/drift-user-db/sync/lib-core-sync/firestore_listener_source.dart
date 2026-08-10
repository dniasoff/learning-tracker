import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

/// [ListenerSource] implementation backed by [FirestoreGateway].
///
/// Opens one broadcast stream per logical collection channel and hands the
/// resulting map to [ListenerSupervisor]. Each call to [openChannels] creates
/// brand-new streams so that a `restart()` cancels old subscriptions before
/// attaching new ones — matching the correctness contract in DNI-335.
///
/// Both the active profile id and the [FirestoreGateway] are resolved lazily
/// on every [openChannels] call rather than captured at construction. This
/// means a `ListenerSupervisor.restart()` after a profile switch — or after
/// the gateway provider rebuilds — re-opens the channels bound to the CURRENT
/// profile and CURRENT gateway. The live listener set is never pinned to a
/// stale profile id (I3 / R1) or a dead gateway handle (I5).
///
/// Phase 2 of the sync-architecture plan (2026-05-21) adds:
///
/// * 9 new channels: `goals`, `learning_ledger`, `learning_order`,
///   `profile_programs`, `learner_profiles`, the three `preferences/*`
///   documents, and `tutor_grants`. Each new channel is a real-time mirror
///   for a collection that was previously pull-only, so multi-device changes
///   become visible without waiting for the next pull-on-launch.
/// * Per-collection [orderField] passed through to the gateway so each
///   listener orders by a meaningful recency field
///   (`updated_at` for snapshot rows, `completed_at`/`event_timestamp` for
///   append-only event collections). Collections without an orderable field
///   fall back to [FirestoreGateway.documentIdOrderField].
/// * Every channel is bounded by the gateway's default page size
///   (`FirestoreGatewayImpl.kListenerPageSize`); a snapshot that saturates
///   the limit emits an `isAtLimit` signal so [ListenerSupervisor] can
///   trigger a recovery pull for that collection.
///
/// Channels exposed (each must have a matching entry in
/// `SyncOrchestratorImpl.channelToKind` and an [EntityMerger]):
///   completions                       — profile subcollection
///   bookmarks                         — profile subcollection
///   settings                          — profile subcollection
///   streak_events                     — per-event collection (W3.37)
///   curriculum_tracks                 — profile subcollection
///   stage_definitions                 — profile subcollection (W2.29)
///   study_day_configs                 — profile subcollection (Phase 1 —
///                                       closes the study-day sync gap)
///   goals                             — profile subcollection (Phase 2)
///   learning_ledger                   — append-only daily ledger (Phase 2)
///   learning_order                    — sort-order overrides (Phase 2)
///   profile_programs                  — curriculum assignments (Phase 2)
///   learner_profiles                  — account-level (Phase 2)
///   preferences/notification_settings — single doc (Phase 2)
///   preferences/gamification_settings — single doc (Phase 2)
///   preferences/ui_preferences        — single doc (Phase 2)
///   tutor_grants                      — root collection scoped to uid (Phase 2)
class FirestoreListenerSource implements ListenerSource {
  FirestoreListenerSource({
    required FirestoreGateway Function() resolveGateway,
    required int Function() resolveProfileId,
  }) : _resolveGateway = resolveGateway,
       _resolveProfileId = resolveProfileId;

  final FirestoreGateway Function() _resolveGateway;
  final int Function() _resolveProfileId;

  /// Per-collection ordering field used by [FirestoreGateway.listenToCollection].
  ///
  /// Most snapshot collections carry an `updated_at` field; append-only event
  /// collections carry a domain-specific timestamp (`completed_at` for
  /// completions, `event_timestamp` for streak events, `created_at` for
  /// learning ledger). Where no orderable field exists the source falls back
  /// to [FirestoreGateway.documentIdOrderField] which orders by document id.
  ///
  /// Public so tests can assert that every wired listener carries an explicit
  /// ordering field — guarantees no listener silently uses `documentId`
  /// fallback unless the underlying schema genuinely lacks a timestamp.
  static const Map<String, String> orderFields = {
    'completions': 'completed_at',
    'bookmarks': 'updated_at',
    'settings': 'updated_at',
    'streak_events': 'event_timestamp',
    'curriculum_tracks': 'state_changed_at',
    'stage_definitions': 'updated_at',
    // Phase 1 addition:
    'study_day_configs': 'updated_at',
    // Phase 2 additions:
    'goals': 'updated_at',
    'learning_ledger': 'created_at',
    'learning_order': 'updated_at',
    'profile_programs': 'updated_at',
    // WS9 Wave-B (C#2) — points spend economy:
    'points_ledger': 'created_at',
    'reward_redemptions': 'updated_at',
  };

  /// Sentinel profile id meaning "no real active profile yet".
  ///
  /// `0` is the legacy/default value [ActiveProfileId] returns transiently —
  /// e.g. during an account switch-back, before the signed-in account's real
  /// active profile resolves, or while a tutored mirror pull is still in
  /// flight. There is NO `users/{uid}/learner_profiles/0` document, so any
  /// per-profile subcollection listener opened against it is denied by the
  /// Firestore rules and floods logcat with PERMISSION_DENIED. The per-profile
  /// channels are therefore skipped while the active profile is this sentinel;
  /// a subsequent `restart()` (fired by the orchestrator when the real profile
  /// resolves) re-opens the full channel set against the concrete profile id.
  static const int noProfileSentinel = 0;

  @override
  Map<String, Stream<Object?>> openChannels() {
    // Resolve once per openChannels() call so every channel in this set is
    // bound to the same (current) gateway and profile id.
    final gateway = _resolveGateway();
    final profileId = _resolveProfileId();

    // Account-level / root-scoped channels are valid regardless of the active
    // profile id (they address `users/{uid}/learner_profiles` and the root
    // `tutor_grants` collection scoped by uid, never `learner_profiles/{id}`).
    // They are always opened — including while [profileId] is the
    // [noProfileSentinel] — so the profile list and tutor grants stay live even
    // before a concrete profile is selected.
    final accountLevel = <String, Stream<Object?>>{
      // `learner_profiles` lives at the ACCOUNT level
      // (users/{uid}/learner_profiles) — the parent of every per-profile
      // subcollection, not a child of any one profile document. The gateway
      // exposes a dedicated `listenToLearnerProfiles` method that builds the
      // correct path (the per-profile-subcollection helper would otherwise
      // yield `users/{uid}/learner_profiles/{profileId}/learner_profiles`).
      'learner_profiles': gateway.listenToLearnerProfiles(),
      // tutor_grants — top-level collection scoped to the caller's uid via
      // a `where` predicate. The gateway handles the OR query (tutor_uid OR
      // parent_uid == auth.uid). Empty stream when not authenticated.
      'tutor_grants': gateway.listenToTutorGrants(),
    };

    // Guard the per-profile channels: there is no `learner_profiles/0`
    // document, so opening them with the sentinel id only produces a
    // PERMISSION_DENIED flood. Return only the account-level channels; the
    // orchestrator restarts the supervisor once the real profile resolves.
    if (profileId == noProfileSentinel) {
      return accountLevel;
    }

    Stream<Object?> coll(String collection) {
      final field =
          orderFields[collection] ?? FirestoreGateway.documentIdOrderField;
      return gateway.listenToCollection(
        profileId: profileId,
        collection: collection,
        orderField: field,
      );
    }

    Stream<Object?> doc(String collection, String docId) =>
        gateway.listenToDocument(
          profileId: profileId,
          collection: collection,
          docId: docId,
        );

    return {
      'completions': coll('completions'),
      'bookmarks': coll('bookmarks'),
      'settings': coll('settings'),
      // W3.37: streak migrated from a single snapshot doc (streak/{id}/data)
      // to an append-only per-event collection (streak_events/{ulid}).
      // The old `streak/data` document no longer exists; subscribing to it
      // would emit null immediately and then never fire again.
      'streak_events': coll('streak_events'),
      'curriculum_tracks': coll('curriculum_tracks'),
      // W2.29 — wire the real-time listener for stage_definitions so that
      // changes pushed from another device propagate without a full pull.
      // Push + pull are already wired; this closes the listener gap.
      'stage_definitions': coll('stage_definitions'),
      // ── Phase 2 additions (sync-architecture-plan 2026-05-21) ───────────
      // Each of these closes a "real-time gap" identified in the audit:
      // before Phase 2 these collections were pull-only, so multi-device
      // changes only surfaced on the next pull-on-launch (worst case: the
      // 5-minute resume throttle window).
      'goals': coll('goals'),
      'learning_ledger': coll('learning_ledger'),
      'learning_order': coll('learning_order'),
      'profile_programs': coll('profile_programs'),
      // Account-level / root-scoped channels (profile-id independent) — see
      // [accountLevel] above; spread in so the full set is returned when a
      // concrete profile is active.
      ...accountLevel,
      // Single-document preference listeners (W3.33 unified docs under
      // `preferences/{scope}`):
      'preferences/notification_settings': doc(
        'preferences',
        'notification_settings',
      ),
      'preferences/gamification_settings': doc(
        'preferences',
        'gamification_settings',
      ),
      'preferences/ui_preferences': doc('preferences', 'ui_preferences'),
      // Phase 1 — listener for the new study_day_configs collection. The
      // per-curriculum/per-track day pattern was local-only before; the
      // merger now consumes pulled rows and reconciles them with the
      // Drift table.
      'study_day_configs': coll('study_day_configs'),
      // WS9 Wave-B (C#2) — points spend economy. Real-time listeners so a
      // child earning on device A, or a parent fulfilling/declining on their
      // device, propagates without waiting for the next pull-on-launch.
      'points_ledger': coll('points_ledger'),
      'reward_redemptions': coll('reward_redemptions'),
    };
  }
}
