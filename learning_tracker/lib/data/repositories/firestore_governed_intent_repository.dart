/// Firestore [GovernedIntentRepository]: a learner's complete governed
/// intent — current settings, every curriculum's main-track docs and its
/// goals — read live (AD-35 inputs, AD-37, AD-38, AD-39; C0 stub map,
/// DNI-470).
///
/// Each intent collection is read completely through [watchCompletePaged]
/// (document-id pages of ≤ 500, no index); the settings through
/// [LearnerSettingsReader]. Nothing is emitted until the settings and
/// EVERY collection have delivered a complete read, so no emission means
/// loading (never a partial intent).
///
/// Assembly is a projection, tolerant of the pre-epic docs these
/// collections still hold:
/// - a main-track doc joins curriculum `curriculum_id` (`curriculum_tracks`:
///   its doc id); a doc without `curriculum_id`, or one its codec rejects,
///   is left out;
/// - a curriculum is present only with a valid `curriculum_tracks` doc;
///   one whose docs cannot assemble (e.g. two `profile_programs` docs) is
///   left out;
/// - goals are read only from the fixed `{curriculumId}_deadline` /
///   `{curriculumId}_pace` docs; any other goal doc is legacy and ignored.
///
/// An error on any input is forwarded as an error event.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// One raw document: its id and storage-form data.
typedef IntentDoc = ({String id, Map<String, Object?> data});

/// The main-track collections of the intent, in assembly order.
const List<String> mainTrackIntentCollections = [
  MainTrack.collection,
  MainTrackProgram.collection,
  MainTrackOrderEntry.collection,
  MainTrackConfigDoc.studyDays,
  MainTrackConfigDoc.stages,
  MainTrackConfigDoc.scope,
];

/// Reads a learner's governed intent from Firestore.
final class FirestoreGovernedIntentRepository
    implements GovernedIntentRepository {
  /// Creates the repository over [firestore] and the [settings] reader.
  FirestoreGovernedIntentRepository({
    required FirebaseFirestore firestore,
    required LearnerSettingsReader settings,
    this.onListenerError,
  }) : _firestore = firestore,
       _settings = settings;

  final FirebaseFirestore _firestore;
  final LearnerSettingsReader _settings;

  /// Called for each stream-level listener failure.
  final void Function(Object error, StackTrace stackTrace)? onListenerError;

  CollectionReference<Map<String, dynamic>> _collection(
    LearnerScope scope,
    String name,
  ) => _firestore
      .collection('users')
      .doc(scope.ownerUid)
      .collection('learner_profiles')
      .doc(scope.profileId)
      .collection(name);

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) {
    final names = [...mainTrackIntentCollections, kGoalsCollection];
    late final StreamController<LearnerIntent> out;
    final subs = <StreamSubscription<Object?>>[];
    LearnerSettings? settings;
    final docs = <String, List<IntentDoc>>{};

    void publish() {
      final s = settings;
      if (s == null || docs.length != names.length) return;
      final LearnerIntent intent;
      try {
        intent = assemble(s, docs);
      } catch (error, stackTrace) {
        out.addError(error, stackTrace);
        return;
      }
      out.add(intent);
    }

    out = StreamController<LearnerIntent>(
      onListen: () {
        subs.add(
          _settings.watch(scope).listen((s) {
            settings = s;
            publish();
          }, onError: out.addError),
        );
        for (final name in names) {
          subs.add(
            watchCompletePaged<IntentDoc>(
              collection: _collection(scope, name),
              decode: (id, data) => (id: id, data: data),
              onError: onListenerError,
            ).listen((read) {
              if (read is CompleteReadReady<IntentDoc>) {
                docs[name] = read.items;
                publish();
              }
            }, onError: out.addError),
          );
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
        await out.close();
      },
    );
    return out.stream;
  }

  /// Assembles the intent from [settings] and the raw docs of each
  /// collection (keyed by collection name). See the library doc for what is
  /// left out.
  static LearnerIntent assemble(
    LearnerSettings settings,
    Map<String, List<IntentDoc>> docs,
  ) {
    final byCurriculum = <String, Map<String, Map<String, Object?>>>{};
    for (final collection in mainTrackIntentCollections) {
      for (final doc in docs[collection] ?? const <IntentDoc>[]) {
        final curriculumId = collection == MainTrack.collection
            ? doc.id
            : doc.data[GovernedKeys.curriculumId];
        if (curriculumId is! String || curriculumId.isEmpty) continue;
        if (!_decodes(collection, doc)) continue;
        byCurriculum.putIfAbsent(curriculumId, () => {})['$collection/'
                '${doc.id}'] =
            doc.data;
      }
    }
    final mainTracks = <String, MainTrackIntent>{};
    for (final MapEntry(key: curriculumId, value: members)
        in byCurriculum.entries) {
      if (!members.containsKey('${MainTrack.collection}/$curriculumId')) {
        continue;
      }
      try {
        mainTracks[curriculumId] = MainTrackIntent.fromStorageDocs(
          curriculumId,
          members,
        );
      } on StorageFormatException {
        continue; // left out (library doc)
      }
    }

    final deadlines = <String, DeadlineGoal>{};
    final paces = <String, PaceGoal>{};
    for (final doc in docs[kGoalsCollection] ?? const <IntentDoc>[]) {
      try {
        if (doc.data[kGoalType] == DeadlineGoal.goalType) {
          final goal = DeadlineGoal.fromStorage(doc.id, doc.data);
          deadlines[goal.curriculumId] = goal;
        } else if (doc.data[kGoalType] == PaceGoal.goalType) {
          final goal = PaceGoal.fromStorage(doc.id, doc.data);
          paces[goal.curriculumId] = goal;
        }
      } on StorageFormatException {
        continue; // a legacy goal doc
      }
    }
    return LearnerIntent(
      settings: settings,
      mainTracks: mainTracks,
      goals: {
        for (final id in {...deadlines.keys, ...paces.keys})
          id: CurriculumGoals(deadline: deadlines[id], pace: paces[id]),
      },
    );
  }

  static bool _decodes(String collection, IntentDoc doc) {
    try {
      switch (collection) {
        case MainTrack.collection:
          MainTrack.fromStorage(doc.id, doc.data);
        case MainTrackProgram.collection:
          MainTrackProgram.fromStorage(doc.id, doc.data);
        case MainTrackOrderEntry.collection:
          MainTrackOrderEntry.fromStorage(doc.id, doc.data);
        default:
          MainTrackConfigDoc.fromStorage(collection, doc.id, doc.data);
      }
      return true;
    } on StorageFormatException {
      return false;
    }
  }
}
