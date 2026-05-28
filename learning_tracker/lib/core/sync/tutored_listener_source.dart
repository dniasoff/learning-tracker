// tutored_listener_source.dart — D3/D5
//
// ListenerSource implementation for a tutored talmid session.
//
// Opens one stream per child collection, all scoped to
// `users/{parentUid}/learner_profiles/{remoteProfileId}/<collection>`.
// The gateway is the PARENT-scoped FirestoreGatewayImpl
// (`activeAccountUid: () => parentUid`), so every read is addressed to the
// parent's Firestore namespace — the tutor's own namespace is never touched.
//
// The channel set mirrors the pull set in PullPipeline.pullForTutoredProfile
// (same collections, same order-field conventions) so listeners and the initial
// pull cover the same ground.

import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

/// [ListenerSource] that opens real-time streams for all of a child's
/// Firestore collections, scoped to the parent's namespace.
///
/// Each call to [openChannels] creates brand-new streams bound to the
/// current [_gateway], so a [ListenerSupervisor.restart] picks up any
/// gateway replacement without leaking stale subscriptions.
class TutoredListenerSource implements ListenerSource {
  TutoredListenerSource({
    required FirestoreGateway gateway,
    required String parentUid,
    required String remoteProfileId,
  }) : _gateway = gateway,
       _parentUid = parentUid,
       _remoteProfileId = remoteProfileId;

  final FirestoreGateway _gateway;
  final String _parentUid;
  final String _remoteProfileId;

  @override
  Map<String, Stream<Object?>> openChannels() {
    Stream<Object?> coll(String collection) {
      final field =
          FirestoreListenerSource.orderFields[collection] ??
          FirestoreGateway.documentIdOrderField;
      return _gateway.listenToChildCollection(
        parentUid: _parentUid,
        remoteProfileId: _remoteProfileId,
        collection: collection,
        orderField: field,
      );
    }

    Stream<Object?> doc(String collection, String docId) =>
        _gateway.listenToChildDocument(
          parentUid: _parentUid,
          remoteProfileId: _remoteProfileId,
          collection: collection,
          docId: docId,
        );

    return {
      'completions': coll('completions'),
      'bookmarks': coll('bookmarks'),
      'settings': coll('settings'),
      'streak_events': coll('streak_events'),
      'curriculum_tracks': coll('curriculum_tracks'),
      'stage_definitions': coll('stage_definitions'),
      'goals': coll('goals'),
      'learning_ledger': coll('learning_ledger'),
      'profile_programs': coll('profile_programs'),
      'study_day_configs': coll('study_day_configs'),
      'points_ledger': coll('points_ledger'),
      'reward_redemptions': coll('reward_redemptions'),
      'preferences/notification_settings': doc(
        'preferences',
        'notification_settings',
      ),
      'preferences/gamification_settings': doc(
        'preferences',
        'gamification_settings',
      ),
      'preferences/ui_preferences': doc('preferences', 'ui_preferences'),
    };
  }
}
