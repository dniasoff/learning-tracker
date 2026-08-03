/// Firestore implementation for study-day configs — Epic B (`docs/
/// firestore-rewrite-map.md`), built to the shape
/// `lib/data/repositories/firestore_stage_definition_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies (resolved-handle constructor, `DocIds`-only doc-ids,
/// entity-owned codec, merge writes, `resilientQueryStream` for the
/// composite-index list query, one-shot-read decode leniency). This doc
/// comment only calls out what is DIFFERENT for this collection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

/// Firestore-backed study-day-configs repository: `users/{uid}/
/// learner_profiles/{profileId}/study_day_configs/{curriculumId}_
/// {dayOfWeek}` (`docs/firestore-rewrite-map.md`, `firestore.rules`
/// `match /study_day_configs/{configId}`).
///
/// **Not wired into the app's production provider yet** — but
/// `FirestoreStudyDayConfigRepositoryAdapter`
/// (`lib/features/scheduler/data/repositories/
/// study_day_config_repository_impl.dart`) exists and does read this class.
/// That adapter itself is not constructed by any real provider (it appears
/// nowhere in `lib/` outside its own definition), so no screen reaches this
/// repository through it yet; the existing Drift-backed `StudyDayConfigDao`
/// (`lib/core/database/daos/study_day_config_dao.dart`) is untouched and
/// keeps serving the app until the rewiring stage.
///
/// **No interface** — same reasoning as the reference repositories: the
/// Drift DAO is being deleted outright, not kept alongside this one, so
/// there is nothing to be substitutable with. Unlike `GoalRepository` /
/// `StageDefinitionRepository`, there was never an abstract
/// `StudyDayConfigRepository` interface in the Drift-era codebase to begin
/// with — `StudyDayConfigDao` was called directly by services — so this
/// class's method set is derived from the DAO's actual call sites, not
/// from trimming an existing interface.
///
/// ## AD-25 re-key
///
/// The doc-id is `{curriculumId}_{dayOfWeek}` (`DocIds.studyDayConfigDocId`)
/// — no `track_id` component. Before Story 2.3's AD-25 re-key the live
/// gateway embedded a third, per-device `track_id` segment; `curriculum_id`
/// is now the sole canonical stable track key for this collection (see
/// `DocIds.studyDayConfigDocId`'s doc comment). This repository never
/// accepts or writes a `trackId`/`track_id` at all, for the same reason the
/// reference stage-definitions repository doesn't: a Drift-local `int`
/// `trackId` has no cross-device meaning, and writing it here would trip
/// the MCF-11 autoincrement-id-in-payload ratchet as a brand-new site.
///
/// ## Trimmed from the Drift-era DAO — not reimplemented
///
/// - **Every `*ForTrack`/`*ByTrack` method
///   (`getConfigsByTrack`/`watchConfigsByTrack`/`isStudyDayForTrack`/
///   `getStudyDaysPerWeekForTrack`/`countStudyDaysInInclusiveDateRangeForTrack`/
///   `seedDefaultsForTrack`/`deleteConfigsForTrack`) is keyed on the
///   Drift-local `int trackId`** — dropped entirely, same reasoning as
///   `FirestoreStageDefinitionRepository` dropping `getStagesByTrack`/
///   `deleteStagesForTrack`. There is no per-device track id left to key by
///   after AD-25; `curriculum_id` is the sole key every method here takes.
/// - **`isStudyDay`, `getStudyDaysPerWeek`, `getLatestUpdatedAt`,
///   `countStudyDaysInInclusiveDateRangeForTrack` do not exist on this
///   class.** Every one of these is a pure derived computation over the
///   list [getConfigsForCurriculum]/[watchConfigsForCurriculum] already
///   return in full (filter by `dayType`, take a max `updatedAt`, count
///   weekdays in a date range) — none of them touch Firestore themselves in
///   the Drift DAO either; they all call `getConfigsByCurriculumAndProfile`
///   first and then compute client-side. Repeating that computation here
///   would duplicate logic that belongs in a scheduler/service layer
///   consuming [StudyDayConfigEntry] lists, not in repository plumbing.
/// - **`upsertDayConfigFromSync`** was a sync-merge-path variant of
///   [setDayConfig] that accepted an explicit remote `updatedAt` for LWW
///   ordering. There is no separate merge/LWW path for a Firestore-native
///   repository — the SDK's own offline-write-queue + `SetOptions(merge:
///   true)` replace it — so only the "now"-stamping [setDayConfig] exists.
///
/// ## What this ADDS relative to the Drift DAO (rules permit it)
///
/// Unlike `goals`/`stage_definitions` (`allow delete: if false`),
/// `study_day_configs`' rules permit owner `delete`
/// (`firestore.rules` `match /study_day_configs/{configId}`). So
/// [replaceAllForCurriculum] can actually implement "replace the whole
/// set" honestly — delete every day absent from the new set, upsert every
/// day present — mirroring `StudyDayConfigDao.replaceAllForTrack`'s
/// delete-then-insert semantics in a single Firestore batch instead of a
/// delete pass followed by a per-row insert loop. This is the one place
/// this repository's capability is a strict superset of what
/// `FirestoreStageDefinitionRepository.resetToDefaults` could do for its
/// own (delete-denied) collection — flagged so the asymmetry isn't
/// mistaken for an oversight.
class FirestoreStudyDayConfigRepository {
  FirestoreStudyDayConfigRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _configs => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('study_day_configs');

  DocumentReference<Map<String, dynamic>> _doc({
    required CurriculumId curriculumId,
    required int dayOfWeek,
  }) => _configs.doc(
    DocIds.studyDayConfigDocId({
      'curriculum_id': curriculumId.storageKey,
      'day_of_week': dayOfWeek,
    }),
  );

  /// The composite-index-requiring query behind
  /// [getConfigsForCurriculum]/[watchConfigsForCurriculum] — `curriculum_id`
  /// equality plus `day_of_week` ordering needs a composite index, same
  /// shape as `FirestoreStageDefinitionRepository`'s `curriculum_id` +
  /// `stage_order` query. Unlike `goals`' `target_date` (nullable — see
  /// `FirestoreGoalRepository`'s doc comment for why THAT repository sorts
  /// client-side instead), `day_of_week` is always present on every
  /// document this repository writes, so ordering by it in the query
  /// itself never silently drops a row.
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _configs
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('day_of_week');

  /// Returns all configured days for [curriculumId], ordered by
  /// `dayOfWeek` (1=Mon..7=Sun).
  Future<List<StudyDayConfigEntry>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row fail
  /// the whole read — same "one bad document should not blank the list"
  /// treatment `FirestoreStageDefinitionRepository._decodeAll` applies.
  List<StudyDayConfigEntry> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <StudyDayConfigEntry>[];
    for (final doc in docs) {
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

  /// Live updates for [curriculumId]'s ordered day-config list.
  /// Resubscribes with bounded exponential backoff if the underlying
  /// listener errors (`resilientQueryStream`).
  Stream<List<StudyDayConfigEntry>> watchConfigsForCurriculum(
    CurriculumId curriculumId,
  ) {
    return resilientQueryStream<StudyDayConfigEntry>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => studyDayConfigEntryFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_study_day_configs_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  /// Creates or updates a single day's config. Merge write — this
  /// collection has a second writer, the tutor-proxy Cloud Function
  /// `tutorUpsertStudyDayConfig` (`functions/src/tutor_writes.ts`), which
  /// also merges and stamps a server `synced_at`; a bare `.set()` from this
  /// client would blow that field away on the next owner write.
  Future<void> setDayConfig({
    required CurriculumId curriculumId,
    required int dayOfWeek,
    required DayType dayType,
  }) async {
    final entry = StudyDayConfigEntry(dayOfWeek: dayOfWeek, dayType: dayType);
    await _doc(curriculumId: curriculumId, dayOfWeek: dayOfWeek).set(
      entry.toFirestore(
        curriculumId: curriculumId,
        updatedAt: DateTimeFactory.nowUtc(), // P5: UTC timestamps
      ),
      SetOptions(merge: true),
    );
  }

  /// Replaces the full set of day configs for [curriculumId] with exactly
  /// [studyDays]: every day present is upserted, every EXISTING day absent
  /// from [studyDays] is deleted. See the class doc comment ("What this
  /// ADDS") for why this collection (unlike `goals`/`stage_definitions`)
  /// can support a genuine replace-all.
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    final existing = await getConfigsForCurriculum(curriculumId);
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final batch = _firestore.batch();
    for (final existingEntry in existing) {
      if (!studyDays.containsKey(existingEntry.dayOfWeek)) {
        batch.delete(
          _doc(curriculumId: curriculumId, dayOfWeek: existingEntry.dayOfWeek),
        );
      }
    }
    for (final day in studyDays.entries) {
      final entry = StudyDayConfigEntry(dayOfWeek: day.key, dayType: day.value);
      batch.set(
        _doc(curriculumId: curriculumId, dayOfWeek: day.key),
        entry.toFirestore(curriculumId: curriculumId, updatedAt: now),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Seeds all 7 days as [DayType.study] if no config exists yet for
  /// [curriculumId]. Idempotent — no-op if any config already exists,
  /// mirroring `FirestoreStageDefinitionRepository.initializeDefaults`.
  /// Writes directly (rather than routing through
  /// [replaceAllForCurriculum]) since the "nothing exists yet" precondition
  /// means there is never anything to delete — no need to pay for a second
  /// read of the (already-known-empty) existing set.
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final existing = await getConfigsForCurriculum(curriculumId);
    if (existing.isNotEmpty) return;
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final batch = _firestore.batch();
    for (var day = 1; day <= 7; day++) {
      final entry = StudyDayConfigEntry(dayOfWeek: day, dayType: DayType.study);
      batch.set(
        _doc(curriculumId: curriculumId, dayOfWeek: day),
        entry.toFirestore(curriculumId: curriculumId, updatedAt: now),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
