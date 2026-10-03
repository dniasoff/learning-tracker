/// Firestore implementation for stage definitions —
/// `users/{uid}/learner_profiles/{profileId}/stage_definitions/
/// {curriculumId}_{stageOrder}`, the AD-38 governed entity
/// `mainTrackStages` (one entity per curriculum, one doc per stage).
///
/// Reads are direct queries; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): a field-level merge of the
/// changed docs with `last_change_id` and one co-written `change_log`
/// entry for the curriculum's stages. This class never writes or deletes a
/// stage document itself.
///
/// ## Composite index and per-document leniency
///
/// [getStagesForCurriculum] / [watchStagesForCurriculum] filter on
/// `curriculum_id` and order by `stage_order`, which needs the composite
/// index in `firestore.indexes.json` (`stage_definitions`: `curriculum_id`
/// ASC + `stage_order` ASC). One malformed document is skipped (and
/// logged), never the whole list.
///
/// ## Removal is a tombstone
///
/// Client `delete` is denied (AD-38). A stage is removed by `ended_at`,
/// written through a logged change; reads skip ended docs and a later
/// write of the same stage order revives it. So a replacement with FEWER
/// stages ([replaceStagesForCurriculum], [resetToDefaults]) now really
/// removes the higher stage orders instead of leaving orphans behind.
///
/// ## Fields
///
/// `curriculum_id`, `stage_order`, `stage_name`, `schedule_type`,
/// `delay_days`, `days_of_week`, `rolling_window_size`, `is_default`
/// (+ `ended_at`); a field a stage no longer has is cleared with an
/// explicit `null`. `updated_at` / `synced_at` are retired from governed
/// docs and never written.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

/// Default stage definitions (לימוד, חזרה א׳, חזרה ב׳).
const _defaultStages = [
  (stageOrder: 1, stageName: kLimudStageName, delayDays: 0),
  (stageOrder: 2, stageName: 'חזרה א׳', delayDays: 1),
  (stageOrder: 3, stageName: 'חזרה ב׳', delayDays: 7),
];

/// Firestore-backed stage-definitions repository (see the library doc
/// comment).
class FirestoreStageDefinitionRepository {
  FirestoreStageDefinitionRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    OwnerGovernedWriter? writer,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _writer = writer,
       _logger = logger ?? AppLogger.instance,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final OwnerGovernedWriter? _writer;
  final AppLogger _logger;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> get _stages => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('stage_definitions');

  static String _docId(CurriculumId curriculumId, int stageOrder) =>
      DocIds.stageDefinitionDocId({
        'curriculum_id': curriculumId.storageKey,
        'stage_order': stageOrder,
      });

  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _stages
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('stage_order');

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

  /// The live stages of [curriculumId], ordered by `stageOrder`.
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every live document in [docs], skipping (and logging) any
  /// single document whose decode fails.
  List<StageDefinition> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <StageDefinition>[];
    for (final doc in docs) {
      final data = doc.data();
      if (!_isLive(data)) continue;
      try {
        results.add(stageDefinitionFromFirestore(data));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_stage_definitions_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Live updates of [getStagesForCurriculum]. Resubscribes with bounded
  /// exponential backoff if the listener errors (`resilientQueryStream`).
  Stream<List<StageDefinition>> watchStagesForCurriculum(
    CurriculumId curriculumId,
  ) {
    return resilientQueryStream<StageDefinition?>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) {
        final data = doc.data();
        return _isLive(data) ? stageDefinitionFromFirestore(data) : null;
      },
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_stage_definitions_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map(
      (stages) => stages.whereType<StageDefinition>().toList(growable: false),
    );
  }

  /// Seeds the default stages (Learn, Chazara 1, Chazara 2) if [curriculumId]
  /// has no live stage yet. Idempotent.
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final existing = await getStagesForCurriculum(curriculumId);
    if (existing.isNotEmpty) return;
    await resetToDefaults(curriculumId);
  }

  /// Replaces [curriculumId]'s stages with the 3 defaults (any higher
  /// stage order is tombstoned).
  Future<void> resetToDefaults(CurriculumId curriculumId) =>
      replaceStagesForCurriculum(curriculumId, [
        for (final d in _defaultStages)
          StageDefinition(
            curriculumId: curriculumId,
            stageOrder: d.stageOrder,
            stageName: d.stageName,
            delayDays: d.delayDays,
            isDefault: true,
          ),
      ]);

  /// Replaces [curriculumId]'s stage set with [stages] (ordered 1..N by the
  /// caller, typically `LearningProcessWizardService`): one logged change
  /// that upserts every given stage and tombstones every live stage whose
  /// order is not among them.
  Future<void> replaceStagesForCurriculum(
    CurriculumId curriculumId,
    List<StageDefinition> stages,
  ) async {
    final change = await planReplaceStages(curriculumId, stages);
    if (change != null) await _apply([change]);
  }

  /// The `mainTrackStages` change [replaceStagesForCurriculum] writes, or
  /// null when there is nothing to write. Used by the one-action Add track
  /// flow (DNI-476 T5).
  Future<GovernedEntityChange?> planReplaceStages(
    CurriculumId curriculumId,
    List<StageDefinition> stages,
  ) async {
    final existing = await getStagesForCurriculum(curriculumId);
    final kept = {for (final s in stages) s.stageOrder};
    final now = _clock();
    final docs = <String, Map<String, Object?>>{
      for (final stage in stages)
        _docId(curriculumId, stage.stageOrder): _fields(stage),
      for (final old in existing)
        if (!kept.contains(old.stageOrder))
          _docId(curriculumId, old.stageOrder): {GovernedKeys.endedAt: now},
    };
    return docs.isEmpty ? null : _change(curriculumId, docs);
  }

  /// Tombstones every live stage of [curriculumId] (one logged change).
  Future<void> deleteStagesForCurriculum(CurriculumId curriculumId) async {
    final existing = await getStagesForCurriculum(curriculumId);
    if (existing.isEmpty) return;
    await _apply([
      OwnerGovernedIntents.endMainTrackDocs(
        entity: GovernedEntity.mainTrackStages,
        curriculumId: curriculumId.storageKey,
        docIds: [for (final s in existing) _docId(curriculumId, s.stageOrder)],
        at: _clock(),
      ),
    ]);
  }

  static Map<String, Object?> _fields(StageDefinition stage) {
    final spec = stage.schedule;
    return {
      'stage_order': stage.stageOrder,
      'stage_name': stage.stageName,
      'schedule_type': spec.storageKey,
      'delay_days': spec.delayDays,
      'days_of_week': spec.daysOfWeek,
      'rolling_window_size': spec.rollingWindowSize,
      'is_default': stage.isDefault,
      GovernedKeys.endedAt: null,
    };
  }

  static GovernedEntityChange _change(
    CurriculumId curriculumId,
    Map<String, Map<String, Object?>> docs,
  ) => OwnerGovernedIntents.mainTrackDocs(
    entity: GovernedEntity.mainTrackStages,
    curriculumId: curriculumId.storageKey,
    docs: docs,
  );

  Future<void> _apply(List<GovernedEntityChange> changes) async {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction(changes));
  }

  /// Every live stage definition of this profile (cross-curriculum).
  /// Unfiltered — no `where()`/`orderBy()`, so no composite index needed.
  Future<List<StageDefinition>> getAllStageDefinitions() async {
    final snapshot = await _stages.get();
    return _decodeAll(snapshot.docs);
  }
}
