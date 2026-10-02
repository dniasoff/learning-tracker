/// Firestore implementation for study-day configs —
/// `users/{uid}/learner_profiles/{profileId}/study_day_configs/
/// {curriculumId}_{dayOfWeek}`, the AD-38 governed entity
/// `mainTrackStudyDays` (one entity per curriculum, one doc per weekday).
///
/// Reads are direct queries; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): a field-level merge of the
/// changed docs with `last_change_id` and one co-written `change_log`
/// entry for the curriculum's study days. This class never writes or
/// deletes a document itself.
///
/// ## Replace-all without deletes
///
/// [replaceAllForCurriculum] upserts every day present and tombstones
/// (`ended_at`) every live day absent; a later write of that day revives
/// it. Client `delete` is denied by the rules (AD-38). Reads skip ended
/// docs. A curriculum has at most 7 docs, so the action always fits one
/// owner batch (AD-54).
///
/// ## Fields
///
/// `curriculum_id`, `day_of_week`, `day_type` (+ `ended_at`).
/// `updated_at` / `synced_at` are retired from governed docs and never
/// written.
///
/// ## Composite index
///
/// [_queryForCurriculum] filters `curriculum_id` and orders by
/// `day_of_week`, which every doc carries, so no row is silently dropped.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

/// Firestore-backed study-day-configs repository (see the library doc
/// comment).
class FirestoreStudyDayConfigRepository {
  FirestoreStudyDayConfigRepository({
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

  CollectionReference<Map<String, dynamic>> get _configs => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('study_day_configs');

  static String _docId(CurriculumId curriculumId, int dayOfWeek) =>
      DocIds.studyDayConfigDocId({
        'curriculum_id': curriculumId.storageKey,
        'day_of_week': dayOfWeek,
      });

  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _configs
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('day_of_week');

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

  /// The live configured days of [curriculumId], ordered by `dayOfWeek`
  /// (1=Mon..7=Sun).
  Future<List<StudyDayConfigEntry>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every live document in [docs], skipping (and logging) any
  /// single document whose decode fails.
  List<StudyDayConfigEntry> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <StudyDayConfigEntry>[];
    for (final doc in docs) {
      if (!_isLive(doc.data())) continue;
      try {
        results.add(studyDayConfigEntryFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_study_day_configs_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Live updates of [getConfigsForCurriculum]. Resubscribes with bounded
  /// exponential backoff if the listener errors (`resilientQueryStream`).
  Stream<List<StudyDayConfigEntry>> watchConfigsForCurriculum(
    CurriculumId curriculumId,
  ) {
    return resilientQueryStream<StudyDayConfigEntry?>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => _isLive(doc.data())
          ? studyDayConfigEntryFromFirestore(doc.data())
          : null,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_study_day_configs_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map((days) => days.whereType<StudyDayConfigEntry>().toList());
  }

  /// Creates or updates a single day's config: one logged change.
  Future<void> setDayConfig({
    required CurriculumId curriculumId,
    required int dayOfWeek,
    required DayType dayType,
  }) => _apply([
    _change(curriculumId, {
      _docId(curriculumId, dayOfWeek): _fields(dayOfWeek, dayType),
    }),
  ]);

  /// Replaces the full set of day configs for [curriculumId] with exactly
  /// [studyDays]: one logged change that upserts every day present and
  /// tombstones every live day absent.
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    final change = await planReplaceAll(
      curriculumId: curriculumId,
      studyDays: studyDays,
    );
    if (change != null) await _apply([change]);
  }

  /// The `mainTrackStudyDays` change [replaceAllForCurriculum] writes, or
  /// null when there is nothing to write. Used by the one-action Add track
  /// flow (DNI-476 T5).
  Future<GovernedEntityChange?> planReplaceAll({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    final existing = await getConfigsForCurriculum(curriculumId);
    final now = _clock();
    final docs = <String, Map<String, Object?>>{
      for (final day in studyDays.entries)
        _docId(curriculumId, day.key): _fields(day.key, day.value),
      for (final old in existing)
        if (!studyDays.containsKey(old.dayOfWeek))
          _docId(curriculumId, old.dayOfWeek): {GovernedKeys.endedAt: now},
    };
    return docs.isEmpty ? null : _change(curriculumId, docs);
  }

  /// Seeds all 7 days as [DayType.study] if no live config exists yet for
  /// [curriculumId]. Idempotent — a no-op once any config exists.
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final existing = await getConfigsForCurriculum(curriculumId);
    if (existing.isNotEmpty) return;
    await _apply([
      _change(curriculumId, {
        for (var day = 1; day <= 7; day++)
          _docId(curriculumId, day): _fields(day, DayType.study),
      }),
    ]);
  }

  static Map<String, Object?> _fields(int dayOfWeek, DayType dayType) => {
    'day_of_week': dayOfWeek,
    'day_type': dayType.storageKey,
    GovernedKeys.endedAt: null,
  };

  static GovernedEntityChange _change(
    CurriculumId curriculumId,
    Map<String, Map<String, Object?>> docs,
  ) => OwnerGovernedIntents.mainTrackDocs(
    entity: GovernedEntity.mainTrackStudyDays,
    curriculumId: curriculumId.storageKey,
    docs: docs,
  );

  Future<void> _apply(List<GovernedEntityChange> changes) async {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction(changes));
  }
}
