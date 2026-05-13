import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';

part 'journey_view_model.freezed.dart';

/// Complete view model for the My Learning Journey screen.
@freezed
abstract class JourneyViewModel with _$JourneyViewModel {
  const factory JourneyViewModel({
    required List<CurriculumJourney> curricula,
    required int totalCompletions,
    required int totalUniqueUnits,
  }) = _JourneyViewModel;
}

/// Journey data for a single curriculum.
@freezed
abstract class CurriculumJourney with _$CurriculumJourney {
  const factory CurriculumJourney({
    required CurriculumId curriculumId,
    required List<UnitCompletion> completions,
    required int uniqueUnitsCompleted,
    required int totalUnitsAvailable,
    required List<MilestoneAchievement> milestones,
  }) = _CurriculumJourney;
}

/// A single unit completion entry from the learning ledger.
@freezed
abstract class UnitCompletion with _$UnitCompletion {
  const factory UnitCompletion({
    required String unitIdentifier,
    required String unitType,
    required String displayNameHe,
    required String displayNameEn,
    required TrackType trackType,
    required DateTime completedAt,
    required int completionNumber,
    required bool isManual,
  }) = _UnitCompletion;
}

/// Pure-string display label for a [UnitCompletion] respecting the Hebrew
/// Terms toggle. Mirrors `curriculumLabelText` for [CurriculumId].
String unitCompletionLabelText(
  WidgetRef ref, {
  required UnitCompletion completion,
}) {
  final useHebrew = ref.watch(useHebrewTermsProvider);
  return useHebrew ? completion.displayNameHe : completion.displayNameEn;
}

/// A milestone achievement (completing a seder or full curriculum).
@freezed
abstract class MilestoneAchievement with _$MilestoneAchievement {
  const factory MilestoneAchievement({
    required String type,
    required String displayName,
    required DateTime achievedAt,
  }) = _MilestoneAchievement;
}

/// Sort mode for the journey screen.
enum JourneySortModeValue { grouped, chronological }
