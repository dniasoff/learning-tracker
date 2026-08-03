/// Firestore adapter for study-day configs — part of Epic C's
/// feature-by-feature rewire onto Firestore (see `lib/data/firestore/
/// repository_providers.dart`'s library doc comment, "Reaching this file
/// from lib/features/** — audit check 102", and `lib/data/repositories/
/// firestore_study_day_config_repository.dart`'s class doc comment for what
/// THIS file wraps).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';

/// Thrown by [FirestoreStudyDayConfigRepositoryAdapter]'s write methods when
/// `firestoreStudyDayConfigRepositoryProvider` resolves to `null` — see
/// `BookmarkRepositoryNotReadyException`'s doc comment
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
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
/// Follows the pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establishes — read that class's doc comment first; this one only calls
/// out what is DIFFERENT here.
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
/// curriculum_track_repository_impl.dart`) documents for the curriculum-
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
  /// profile). See `FirestoreBookmarkRepositoryAdapter._resolveOrNull`'s doc
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
  Future<void> setDayConfig({
    required CurriculumId curriculumId,
    required int dayOfWeek,
    required DayType dayType,
  }) async {
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
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
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
