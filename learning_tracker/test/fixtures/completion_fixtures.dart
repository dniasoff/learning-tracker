/// Test fixtures for Completion
/// Factory methods for creating test data with sensible defaults
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Factory for creating test Completion instances (Drift Companion objects)
class CompletionFixtures {
  /// Creates a test completion for the "Learn" stage (stage order 1)
  static CompletionsCompanion learnStage({
    Value<int> id = const Value.absent(),
    String? curriculumId,
    int sefariaRef = 1,
    int stageId = 1,
    String trackType = 'personal',
    DateTime? completedAt,
    Value<int> points = const Value(10),
  }) {
    return CompletionsCompanion.insert(
      id: id,
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      completedAt: completedAt ?? DateTime.now().toUtc(),
      points: points,
    );
  }

  /// Creates a test completion for "Chazara 1" stage (stage order 2)
  static CompletionsCompanion chazara1({
    Value<int> id = const Value.absent(),
    String? curriculumId,
    int sefariaRef = 1,
    int stageId = 2,
    String trackType = 'personal',
    DateTime? completedAt,
    Value<int> points = const Value(5),
  }) {
    return CompletionsCompanion.insert(
      id: id,
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      completedAt: completedAt ?? DateTime.now().toUtc(),
      points: points,
    );
  }

  /// Creates a test completion for school track
  static CompletionsCompanion schoolTrack({
    Value<int> id = const Value.absent(),
    String? curriculumId,
    int sefariaRef = 1,
    int stageId = 1,
    DateTime? completedAt,
    Value<int> points = const Value(10),
  }) {
    return CompletionsCompanion.insert(
      id: id,
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'school',
      completedAt: completedAt ?? DateTime.now().toUtc(),
      points: points,
    );
  }

  /// Creates a test completion for tutor track
  static CompletionsCompanion tutorTrack({
    Value<int> id = const Value.absent(),
    String? curriculumId,
    int sefariaRef = 1,
    int stageId = 1,
    DateTime? completedAt,
    Value<int> points = const Value(10),
  }) {
    return CompletionsCompanion.insert(
      id: id,
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'tutor',
      completedAt: completedAt ?? DateTime.now().toUtc(),
      points: points,
    );
  }

  /// Creates a completion from a specific date (for testing streaks/scheduling)
  static CompletionsCompanion fromDate({
    Value<int> id = const Value.absent(),
    String? curriculumId,
    int sefariaRef = 1,
    int stageId = 1,
    String trackType = 'personal',
    required DateTime completedAt,
    Value<int> points = const Value(10),
  }) {
    return CompletionsCompanion.insert(
      id: id,
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      completedAt: completedAt.toUtc(), // Ensure UTC per P5
      points: points,
    );
  }
}
