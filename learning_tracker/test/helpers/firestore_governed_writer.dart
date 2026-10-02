/// An [OwnerGovernedWriter] for owner-repository tests (DNI-476): the real
/// `DefaultGovernedLearningCommands` over the real
/// `FirestoreChangeLogRepository` / `FirestoreSubTrackRepository`, all on
/// the test's `FakeFirebaseFirestore`, so a repository write lands exactly
/// as it would in production — field-level merges, `last_change_id` and a
/// co-written `change_log` entry per entity.
///
/// Oversized actions (an entity over the AD-54 budget) go to
/// [ApplyingOversizedPort], which applies them to the same fake (as the
/// `ownerOversizedGovernedWrite` callable would) and records each request;
/// set [ApplyingOversizedPort.online] to false to simulate offline.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';

/// A fixed ULID profile id for owner-repository tests (AD-24).
const governedTestProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

/// The governed-writer test clock.
final governedTestNow = DateTime.utc(2026, 9, 10, 12);

/// Applies oversized actions to the fake Firestore and records them.
final class ApplyingOversizedPort implements OversizedGovernedWritePort {
  /// Creates the port over [firestore].
  ApplyingOversizedPort(this.firestore);

  /// The fake the requests are applied to.
  final FakeFirebaseFirestore firestore;

  /// Every request sent, in order.
  final List<OversizedGovernedWrite> requests = [];

  /// When false, every write throws [OnlineRequiredException].
  bool online = true;

  @override
  Future<GovernedWriteReceipt> write(
    LearnerScope scope,
    OversizedGovernedWrite request,
  ) async {
    if (!online) throw const OnlineRequiredException();
    requests.add(request);
    final profile = firestore.doc(scope.profilePath);
    final batch = firestore.batch();
    for (final entry in request.entries) {
      for (final doc in entry.change.docs) {
        batch.set(
          profile.collection(doc.collection).doc(doc.docId),
          toFirestoreMap({...doc.fields, 'last_change_id': entry.entryId}),
          SetOptions(merge: true),
        );
      }
    }
    await batch.commit();
    return GovernedWriteReceipt(
      actionId: request.actionId,
      changeIds: [for (final e in request.entries) e.entryId],
    );
  }
}

/// The owner governed writer under test (see the library doc comment).
final class FirestoreGovernedWriter implements OwnerGovernedWriter {
  /// Creates the writer for `users/[uid]/learner_profiles/[profileId]`.
  FirestoreGovernedWriter(
    this.firestore, {
    required String uid,
    String profileId = governedTestProfileId,
    DateTime? now,
  }) : scope = LearnerScope(ownerUid: uid, profileId: profileId),
       oversized = ApplyingOversizedPort(firestore) {
    final changeLog = FirestoreChangeLogRepository(firestore: firestore);
    final at = now ?? governedTestNow;
    commands = DefaultGovernedLearningCommands(
      scope: scope,
      actor: Actor(uid: uid, role: ActorRole.parent, displayName: ''),
      changeLog: changeLog,
      subTracks: FirestoreSubTrackRepository(firestore: firestore),
      reader: changeLog,
      oversized: oversized,
      clock: () => at,
      newUlid: newUlid,
    );
  }

  /// The fake Firestore.
  final FakeFirebaseFirestore firestore;

  /// The scope written to.
  final LearnerScope scope;

  /// The oversized-callable fake.
  final ApplyingOversizedPort oversized;

  /// The commands every write goes through.
  late final DefaultGovernedLearningCommands commands;

  /// Every action handed to the writer, in order.
  final List<GovernedAction> actions = [];

  /// Every result returned, in order.
  final List<CaptureResult> results = [];

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async {
    actions.add(action);
    final result = await commands.applyGovernedChange(action);
    results.add(result);
    return result;
  }

  /// Every `change_log` entry of the scope, decoded, in id order.
  Future<List<ChangeLogEntry>> entries() async {
    final snapshot = await firestore
        .doc(scope.profilePath)
        .collection('change_log')
        .orderBy(FieldPath.documentId)
        .get();
    return [
      for (final doc in snapshot.docs)
        ChangeLogEntry.fromStorage(doc.id, fromFirestoreMap(doc.data())),
    ];
  }

  /// The entries written by the last successful action, in action order.
  Future<List<ChangeLogEntry>> lastEntries() async {
    final last = results.whereType<CaptureSuccess>().last;
    final byId = {for (final e in await entries()) e.id: e};
    return [for (final id in last.changeIds) byId[id]!];
  }

  /// The raw stored fields of `{collection}/{docId}`, or null.
  Future<Map<String, dynamic>?> doc(String collection, String docId) async {
    final snapshot = await firestore
        .doc(scope.profilePath)
        .collection(collection)
        .doc(docId)
        .get();
    return snapshot.data();
  }
}
