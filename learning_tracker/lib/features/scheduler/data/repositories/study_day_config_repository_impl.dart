/// Firestore adapter for study-day configs — part of Epic C's
/// feature-by-feature rewire onto Firestore (see `lib/data/firestore/
/// repository_providers.dart`'s library doc comment, "Reaching this file
/// from lib/features/** — audit check 102", and `lib/data/repositories/
/// firestore_study_day_config_repository.dart`'s class doc comment for what
/// THIS file wraps).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

/// Thrown by [FirestoreStudyDayConfigRepositoryAdapter]'s write methods when
/// `firestoreStudyDayConfigRepositoryProvider` resolves to `null` — see
/// not-ready exception's doc comment
/// for the read-vs-write split this mirrors: reads reuse a natural "nothing
/// yet" value (`[]`), writes have no such value and throw instead.
class StudyDayConfigRepositoryNotReadyException implements Exception {
  const StudyDayConfigRepositoryNotReadyException();

  @override
  String toString() =>
      'StudyDayConfigRepositoryNotReadyException: '
      'firestoreStudyDayConfigRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot '
      'complete a study-day-config write until one is active.';
}

/// Firestore-backed adapter over [FirestoreStudyDayConfigRepository].
/// Uses the shared provider re-resolution pattern.
///
/// ## No domain interface to `implements` — none ever existed
///
/// Per [FirestoreStudyDayConfigRepository]'s own class doc comment: "unlike
/// `GoalRepository` / `StageDefinitionRepository`, there was never an
/// abstract `StudyDayConfigRepository` interface in the Drift-era codebase
/// to begin with" — `StudyDayConfigDao`
/// (`lib/core/database/daos/study_day_config_dao.dart`) is called directly
/// by `study_day_config_providers.dart`
/// (`lib/features/scheduler/presentation/providers/`),
/// `CurriculumActivationService`
/// (`lib/features/tracks/domain/services/curriculum_activation_service.dart`)
/// and `TrackCreationService`/`TrackEditService`
/// (`lib/features/tracks/setup/domain/services/`). This class's method set
/// therefore mirrors [FirestoreStudyDayConfigRepository]'s own surface
/// directly (standalone, not `implements` anything) rather than trimming an
/// existing interface — the same status
/// [FirestoreCurriculumTrackRepositoryAdapter]
/// (`lib/features/tracks/setup/data/repositories/
/// track lifecycle. Ready for a future task to extract a genuine
/// `StudyDayConfigRepository` interface and rewire those four call sites —
/// out of this task's `data/repositories/`-only scope.
///
/// ## Not-ready semantics
///
/// [getConfigsForCurriculum] reuses the interface's own `[]` "nothing yet"
/// value. [setDayConfig]/[replaceAllForCurriculum]/[initializeDefaults] have
/// no such value and throw [StudyDayConfigRepositoryNotReadyException]
/// instead. [watchConfigsForCurriculum] resolves the provider once via
/// [_resolveOrNull] and then either forwards to the resolved repository's
/// own stream or falls back to a single `[]` emission — see
/// [FirestoreCurriculumTrackRepositoryAdapter]'s class doc comment
/// ("Not-ready semantics") for the one-shot-resolve limitation this shares
/// with every other `watch*` method built in this wave.
class FirestoreStudyDayConfigRepositoryAdapter {
  FirestoreStudyDayConfigRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreStudyDayConfigRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). See this adapter's `_resolveOrNull`'s doc
  /// comment for why this re-reads on every call rather than caching.
  Future<FirestoreStudyDayConfigRepository?> _resolveOrNull() {
    return _ref.read(firestoreStudyDayConfigRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws
  /// [StudyDayConfigRepositoryNotReadyException] instead of returning
  /// `null` — for the three write methods; see the class doc comment.
  Future<FirestoreStudyDayConfigRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const StudyDayConfigRepositoryNotReadyException();
    }
    return repo;
  }

  /// Returns all configured days for [curriculumId], ordered by
  /// `dayOfWeek`. `[]` when not ready.
  Future<List<StudyDayConfigEntry>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    return repo.getConfigsForCurriculum(curriculumId);
  }

  /// Live updates for [curriculumId]'s ordered day-config list. See the
  /// class doc comment's "Not-ready semantics" section.
  Stream<List<StudyDayConfigEntry>> watchConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async* {
    final repo = await _resolveOrNull();
    if (repo == null) {
      yield const [];
      return;
    }
    yield* repo.watchConfigsForCurriculum(curriculumId);
  }

  /// Creates or updates a single day's config. Throws
  /// [StudyDayConfigRepositoryNotReadyException] when not ready.
  ///
  /// In a tutored session the write is the governed
  /// `tutorUpsertStudyDayConfig` callable (Story 1.24, DNI-486), never a
  /// client write to the talmid's tree.
  Future<void> setDayConfig({
    required CurriculumId curriculumId,
    required int dayOfWeek,
    required DayType dayType,
  }) async {
    if (_ref.read(activeTutoredProfileSelectionProvider) != null) {
      return tutorReplaceStudyDays(
        _ref,
        curriculumId: curriculumId,
        studyDays: {dayOfWeek: dayType},
        existing: const [],
      );
    }
    final repo = await _resolve();
    await repo.setDayConfig(
      curriculumId: curriculumId,
      dayOfWeek: dayOfWeek,
      dayType: dayType,
    );
  }

  /// Replaces the full set of day configs for [curriculumId] with exactly
  /// [studyDays]. Throws [StudyDayConfigRepositoryNotReadyException] when
  /// not ready.
  ///
  /// In a tutored session the replace is governed callables only
  /// (Story 1.24, DNI-486): see [tutorReplaceStudyDays].
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    if (_ref.read(activeTutoredProfileSelectionProvider) != null) {
      return tutorReplaceStudyDays(
        _ref,
        curriculumId: curriculumId,
        studyDays: studyDays,
        existing: await getConfigsForCurriculum(curriculumId),
      );
    }
    final repo = await _resolve();
    await repo.replaceAllForCurriculum(
      curriculumId: curriculumId,
      studyDays: studyDays,
    );
  }

  /// Seeds all 7 days as [DayType.study] if no config exists yet for
  /// [curriculumId]. Throws [StudyDayConfigRepositoryNotReadyException]
  /// when not ready.
  Future<void> initializeDefaults(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.initializeDefaults(curriculumId);
  }
}

/// A tutor's study-day write (Story 1.24, DNI-486): upserts [studyDays]
/// and tombstones every [existing] day absent from it as ONE governed
/// `tutorReplaceStudyDays` action after the tutor preflight. Throws when
/// the preflight refuses or the callable fails; then nothing was written.
Future<void> tutorReplaceStudyDays(
  Ref ref, {
  required CurriculumId curriculumId,
  required Map<int, DayType> studyDays,
  required List<StudyDayConfigEntry> existing,
}) async {
  final writes = await requireTutorGovernedWrites(ref);
  String docId(int day) => DocIds.studyDayConfigDocId({
    'curriculum_id': curriculumId.storageKey,
    'day_of_week': day,
  });
  await writes.replaceStudyDays(
    curriculumId: curriculumId.storageKey,
    upserts: [
      for (final MapEntry(key: day, value: type) in studyDays.entries)
        (
          docId: docId(day),
          data: StudyDayConfigEntry(
            dayOfWeek: day,
            dayType: type,
          ).toFirestore(curriculumId: curriculumId),
        ),
    ],
    removedDocIds: [
      for (final entry in existing)
        if (!studyDays.containsKey(entry.dayOfWeek)) docId(entry.dayOfWeek),
    ],
  );
}
