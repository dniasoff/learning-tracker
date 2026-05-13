import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

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
///
/// Display text is resolved at render time via [CurriculumLabel] — the model
/// carries only structural keys so the label can be locale-aware and
/// transliteration-variant-aware without baking strings into stored data.
///
/// * [entryScope] — the logical scope of the entry (e.g. `'masechta'`,
///   `'seder'`, `'sefer'`). Maps to the hierarchy level used by
///   [CurriculumLabel.level].
/// * [entryKey] — the raw identifier value (e.g. `'Berakhot'`, `'Zeraim'`).
/// * [parentL1Key] — the parent level-1 value when [entryScope] is at level 2
///   (e.g. the seder name for a masechta). `null` for level-1 entries.
@freezed
abstract class UnitCompletion with _$UnitCompletion {
  const factory UnitCompletion({
    required String unitIdentifier,
    required String entryScope,
    required String entryKey,
    String? parentL1Key,
    required TrackType trackType,
    required DateTime completedAt,
    required int completionNumber,
    required bool isManual,
  }) = _UnitCompletion;
}

/// Map a [UnitCompletion.entryScope] string to the integer level index used by
/// [CurriculumLabel.level]. Level-1 scopes (seder, book-level) return 1;
/// level-2 scopes (masechta, sefer, parsha) return 2. Unknown scopes default
/// to 2 so they still render something sensible.
int unitCompletionLevel(String entryScope) {
  switch (entryScope) {
    case 'seder':
    case 'book':
      return 1;
    default:
      // masechta, sefer, parsha, and any future named level-2 type.
      return 2;
  }
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
