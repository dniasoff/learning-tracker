import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'journey_view_model.freezed.dart';

/// Complete view model for the Siyumim & Milestones screen.
///
/// Exposes a per-curriculum breakdown plus three level-split counters that
/// the screen surfaces at the top:
///
/// * `unitLevelSiyumimCount` — Masechta / Sefer / Siman / Hilchos siyumim
///   across all curricula.
/// * `aggregateLevelSiyumimCount` — Seder / Chelek siyumim across all
///   curricula (only emitted for curricula that expose an aggregate
///   hierarchy level — e.g. Mishnayos / Bavli / Yerushalmi / Mishneh Torah).
/// * `curriculumLevelSiyumimCount` — full-curriculum siyumim (Siyum HaShas,
///   Siyum HaTorah, etc.) across all curricula.
///
/// The counters are derived from the same `MilestoneAchievement` records
/// surfaced inside each [CurriculumJourney]; they live on the top-level
/// view model so the UI can render them without re-traversing the tree.
@freezed
abstract class JourneyViewModel with _$JourneyViewModel {
  const factory JourneyViewModel({
    required List<CurriculumJourney> curricula,
    required int totalCompletions,
    required int totalUniqueUnits,
    required int unitLevelSiyumimCount,
    required int aggregateLevelSiyumimCount,
    required int curriculumLevelSiyumimCount,
  }) = _JourneyViewModel;
}

/// Journey data for a single curriculum.
///
/// The `milestones` list contains entries at all three levels — unit,
/// aggregate, and curriculum. Use [MilestoneAchievement.level] to filter or
/// group them in the UI.
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

/// The celebration level a [MilestoneAchievement] belongs to.
///
/// Used by the Siyumim & Milestones screen to:
/// * Split the top counters three ways (unit / aggregate / curriculum).
/// * Group rows within each curriculum hierarchically (curriculum at the
///   top, aggregates below, standalone unit rows last).
enum MilestoneLevel {
  /// Single-unit siyum: masechta, sefer, siman, hilchos.
  unit,

  /// Mid-level aggregate siyum: seder, chelek. Only emitted for curricula
  /// whose content data exposes an aggregate level between unit and
  /// curriculum (e.g. Mishnayos / Bavli / Yerushalmi).
  aggregate,

  /// Full-curriculum siyum: Siyum HaShas, Siyum HaTorah, Siyum HaMishnayos,
  /// etc.
  curriculum,
}

/// A milestone achievement — a siyum at one of three levels.
///
/// All three levels share the same record shape so the screen can render
/// them through a single widget. [level] partitions them; [aggregateKey]
/// captures which level-1 grouping an aggregate-level milestone covers so
/// the screen can collapse contained unit-level milestones into it.
@freezed
abstract class MilestoneAchievement with _$MilestoneAchievement {
  const factory MilestoneAchievement({
    /// Legacy string discriminator kept for backwards compatibility with
    /// older widgets that still inspect it:
    /// * `'unit_complete'`     — equivalent to [MilestoneLevel.unit]
    /// * `'seder_complete'`    — equivalent to [MilestoneLevel.aggregate]
    /// * `'curriculum_complete'` — equivalent to [MilestoneLevel.curriculum]
    ///
    /// New code SHOULD prefer [level].
    required String type,

    /// Which celebration level this milestone represents.
    required MilestoneLevel level,

    /// Which curriculum this milestone belongs to (so the renderer can
    /// resolve curriculum-specific labels like "Siyum HaShas" vs
    /// "Siyum HaTorah" without looking the parent up separately).
    required CurriculumId curriculumId,

    /// Generic display name for backwards-compat callers. New code SHOULD
    /// use the [level] + [curriculumId] + [unitKey] / [aggregateKey] to
    /// resolve a localized label via `domainTermLabels(ref)`.
    required String displayName,

    /// When [level] is [MilestoneLevel.unit], the unit's raw key
    /// (e.g. masechta name `'Berakhot'`) — used by the renderer to call
    /// `siyumMasechta(name)`, `siyumSefer(name)`, etc.
    String? unitKey,

    /// The unit's `entryScope` value (e.g. `'masechta'`, `'sefer'`,
    /// `'siman'`, `'hilchos'`). Lets the renderer pick the right per-scope
    /// label template.
    String? unitScope,

    /// The parent level-1 value for a unit-level milestone (e.g. the seder
    /// name for a masechta). Lets the screen collapse unit rows inside
    /// their parent aggregate when an aggregate siyum has been earned.
    String? parentAggregateKey,

    /// When [level] is [MilestoneLevel.aggregate], the level-1 key the
    /// aggregate represents (e.g. seder name `'Zeraim'`). Used both to
    /// render the label ("Siyum Seder Zeraim") and to match contained
    /// unit-level milestones for hierarchical grouping.
    String? aggregateKey,

    /// The set of unit keys this aggregate-level milestone contains. Used
    /// by the expandable row to list "All N masechtos complete" with the
    /// contained masechtos shown when expanded.
    @Default(<String>[]) List<String> containedUnitKeys,

    required DateTime achievedAt,
  }) = _MilestoneAchievement;
}

/// Sort mode for the journey screen.
enum JourneySortModeValue { grouped, chronological }
