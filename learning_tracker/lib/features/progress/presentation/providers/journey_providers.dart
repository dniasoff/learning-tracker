import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journey_providers.g.dart';

// ---------------------------------------------------------------------------
// Helpers — derive UnitCompletion structural keys from ledger rows.
// ---------------------------------------------------------------------------

/// Entry scope: the ledger's [entryScope] string verbatim (e.g. `'masechta'`).
String _entryScope(LearningLedgerData e) => e.entryScope;

/// Entry key: the ledger's [unitIdentifier] verbatim.
String _entryKey(LearningLedgerData e) => e.unitIdentifier;

/// Look up the level-1 parent of a level-2 entry from the content item list.
///
/// The ledger row doesn't store the parent explicitly. We scan the loaded
/// content for the first item whose [level2] matches the entry's identifier
/// and return its [level1]. Returns `null` for level-1 scope types.
String? _parentL1Key(LearningLedgerData e, List<ContentItem> content) {
  const level2Types = {'masechta', 'sefer', 'parsha', 'book'};
  if (!level2Types.contains(e.entryScope)) return null;
  for (final item in content) {
    if (item.level2 == e.unitIdentifier) return item.level1;
  }
  return null;
}

/// Returns true when [curriculum]'s content data exposes an aggregate
/// (level-1) grouping above its unit-level (level-2) leaves.
///
/// The redesign brief calls out three categories:
/// * **Three-tier** — Mishnayos / Bavli / Yerushalmi / Mishneh Torah expose
///   level-1 + level-2; aggregate siyumim (seder, sefer-of-rambam) are emitted.
/// * **Two-tier (sefer at the top)** — Chumash / Nach / Tanach / Mussar /
///   Mishna Berurah expose only sefer-level leaves; only unit + curriculum
///   siyumim are emitted.
///
/// The decision is made from the loaded content rather than hardcoded so
/// the screen stays correct if a curriculum's hierarchy changes.
bool _hasAggregateLevel(List<ContentItem> content, CurriculumId curriculum) {
  if (curriculum == CurriculumId.mussar) return false;
  // If at least one content item has a non-null level2 AND more than one
  // distinct level1 grouping that contains level2 children, the curriculum
  // has a meaningful aggregate tier.
  final groups = <String, Set<String>>{};
  for (final item in content) {
    if (item.level2 != null) {
      groups.putIfAbsent(item.level1, () => <String>{}).add(item.level2!);
    }
  }
  if (groups.isEmpty) return false;
  // A single level1 with all children is effectively flat (e.g. Chumash where
  // the unit IS a sefer).
  return groups.length > 1 || groups.values.any((s) => s.length > 1);
}

/// Sort mode toggle for journey screen (grouped vs chronological).
@riverpod
class JourneySortModeNotifier extends _$JourneySortModeNotifier {
  @override
  JourneySortModeValue build() => JourneySortModeValue.grouped;

  void toggle() {
    state = state == JourneySortModeValue.grouped
        ? JourneySortModeValue.chronological
        : JourneySortModeValue.grouped;
  }

  void setMode(JourneySortModeValue mode) {
    state = mode;
  }
}

/// Looks up a profile by ID, used when viewing another user's journey.
final profileByIdProvider = FutureProvider.autoDispose
    .family<ProfileModel?, int>((ref, profileId) async {
      final repo = ref.watch(profileRepositoryProvider);
      return repo.getProfileById(profileId);
    });

/// Provider for learning ledger entries for a given profile.
final learningLedgerProvider = FutureProvider.autoDispose
    .family<List<LearningLedgerData>, int>((ref, profileId) async {
      final database = ref.watch(userDatabaseProvider);
      return database.learningLedgerDao.getEntriesByProfile(profileId);
    });

/// Computes the full JourneyViewModel for a given profile.
@riverpod
Future<JourneyViewModel> journeyViewModel(Ref ref, int profileId) async {
  ref.watch<int>(completionCommittedProvider);
  final ledgerEntries = await ref.watch(
    learningLedgerProvider(profileId).future,
  );
  final activeCurricula = await ref.watch(activeCurriculaProvider.future);

  final curricula = <CurriculumJourney>[];
  var totalCompletions = 0;
  final allUniqueUnits = <String>{};
  var unitLevelSiyumimCount = 0;
  var aggregateLevelSiyumimCount = 0;
  var curriculumLevelSiyumimCount = 0;

  for (final curriculum in activeCurricula) {
    final entriesForCurriculum = ledgerEntries
        .where((e) => e.curriculumId == curriculum.storageKey)
        .toList();

    // Get total available units from content repository
    final content = await ref.watch(
      curriculumContentProvider(curriculum).future,
    );
    final totalUnits = _countTotalUnits(content, curriculum);

    // Build completions list
    final completions = entriesForCurriculum
        .map(
          (e) => UnitCompletion(
            unitIdentifier: e.unitIdentifier,
            entryScope: _entryScope(e),
            entryKey: _entryKey(e),
            parentL1Key: _parentL1Key(e, content),
            trackType: TrackType.fromStorageKey(e.trackType),
            completedAt: e.completedAt,
            completionNumber: e.completionNumber,
            isManual: e.isManual,
          ),
        )
        .toList();

    // Count unique units
    final uniqueUnits = entriesForCurriculum
        .map((e) => e.unitIdentifier)
        .toSet();

    // Detect milestones at all three levels.
    final milestones = _detectMilestones(
      ref,
      entriesForCurriculum,
      content,
      curriculum,
    );

    // Tally the level breakdown for the top-of-screen counters.
    for (final m in milestones) {
      switch (m.level) {
        case MilestoneLevel.unit:
          unitLevelSiyumimCount++;
        case MilestoneLevel.aggregate:
          aggregateLevelSiyumimCount++;
        case MilestoneLevel.curriculum:
          curriculumLevelSiyumimCount++;
      }
    }

    totalCompletions += completions.length;
    allUniqueUnits.addAll(uniqueUnits);

    if (completions.isNotEmpty || totalUnits > 0) {
      curricula.add(
        CurriculumJourney(
          curriculumId: curriculum,
          completions: completions,
          uniqueUnitsCompleted: uniqueUnits.length,
          totalUnitsAvailable: totalUnits,
          milestones: milestones,
        ),
      );
    }
  }

  return JourneyViewModel(
    curricula: curricula,
    totalCompletions: totalCompletions,
    totalUniqueUnits: allUniqueUnits.length,
    unitLevelSiyumimCount: unitLevelSiyumimCount,
    aggregateLevelSiyumimCount: aggregateLevelSiyumimCount,
    curriculumLevelSiyumimCount: curriculumLevelSiyumimCount,
  );
}

/// Count total available units for a curriculum.
///
/// For most curricula, units are level2 (masechtos).
/// For mussar, units are level1 (sefarim).
int _countTotalUnits(List<ContentItem> content, CurriculumId curriculum) {
  if (curriculum == CurriculumId.mussar) {
    return content.map((c) => c.level1).toSet().length;
  }
  return content
      .where((c) => c.level2 != null)
      .map((c) => c.level2!)
      .toSet()
      .length;
}

/// Detect milestone achievements from ledger entries.
///
/// Emits up to three levels (per `MilestoneLevel`):
///
/// 1. **Unit-level** — one milestone per ledger entry whose `entryScope`
///    matches a content-data leaf for this curriculum (`masechta` for
///    Mishnayos/Bavli/Yerushalmi, `sefer` for Chumash/Nach/Tanach/Mussar,
///    `siman` for Mishna Berurah, `hilchos` for Mishneh Torah).
/// 2. **Aggregate-level** — one milestone per level-1 grouping whose every
///    contained unit appears in the unit-level set. Only emitted when the
///    curriculum's content data exposes a meaningful level-1 tier
///    (see [_hasAggregateLevel]).
/// 3. **Curriculum-level** — one milestone when every unit in the curriculum
///    has been completed.
///
/// The function preserves the existing seder / curriculum detection
/// semantics — the new behaviour is purely additive (unit-level emission
/// and richer metadata on each row).
List<MilestoneAchievement> _detectMilestones(
  Ref ref,
  List<LearningLedgerData> entries,
  List<ContentItem> content,
  CurriculumId curriculum,
) {
  final milestones = <MilestoneAchievement>[];
  if (entries.isEmpty) return milestones;

  // Milestones are curriculum/seder completion signals and should be based on
  // unit-level ledger entries only. Item-level lifetime markers (e.g. daf/perek)
  // must not artificially complete a curriculum milestone.
  // For mussar the unit IS a sefer (level-1), so accept level-1 scopes there.
  const unitScopes = {'masechta', 'sefer', 'siman', 'hilchos'};
  final unitLevelEntries = entries
      .where((e) => unitScopes.contains(e.entryScope))
      .toList();
  final completedUnits = unitLevelEntries.map((e) => e.unitIdentifier).toSet();

  // ── Build parent → child map from content data ─────────────────────────
  // Maps level-1 keys (e.g. seder name) → set of level-2 child keys
  // (e.g. masechta names within that seder). For two-tier curricula
  // (Chumash / Nach / Tanach / Mussar) this stays empty.
  final aggregateGroups = <String, Set<String>>{};
  for (final item in content) {
    if (item.level2 != null) {
      aggregateGroups.putIfAbsent(item.level1, () => {}).add(item.level2!);
    }
  }

  // Look up the parent level-1 for a given unit key.
  String? parentL1For(String unitKey) {
    for (final entry in aggregateGroups.entries) {
      if (entry.value.contains(unitKey)) return entry.key;
    }
    return null;
  }

  // ── 1. Unit-level milestones ─────────────────────────────────────────────
  // One per unit-level ledger entry. The screen filters these by level when
  // building counters and renders them with the per-scope siyum label
  // (siyumMasechta / siyumSefer / siyumSiman / siyumHilchos).
  for (final entry in unitLevelEntries) {
    milestones.add(
      MilestoneAchievement(
        type: 'unit_complete',
        level: MilestoneLevel.unit,
        curriculumId: curriculum,
        displayName: entry.unitIdentifier,
        unitKey: entry.unitIdentifier,
        unitScope: entry.entryScope,
        parentAggregateKey: parentL1For(entry.unitIdentifier),
        achievedAt: entry.completedAt,
      ),
    );
  }

  // ── 2. Aggregate-level milestones ────────────────────────────────────────
  // Only emitted when the curriculum has a meaningful aggregate level.
  if (_hasAggregateLevel(content, curriculum)) {
    for (final group in aggregateGroups.entries) {
      if (group.value.every((unit) => completedUnits.contains(unit))) {
        // Latest completion date among the units in this group.
        final groupCompletions =
            unitLevelEntries
                .where((e) => group.value.contains(e.unitIdentifier))
                .toList()
              ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        if (groupCompletions.isNotEmpty) {
          milestones.add(
            MilestoneAchievement(
              type: 'seder_complete',
              level: MilestoneLevel.aggregate,
              curriculumId: curriculum,
              displayName: group.key,
              aggregateKey: group.key,
              containedUnitKeys: group.value.toList()..sort(),
              achievedAt: groupCompletions.first.completedAt,
            ),
          );
        }
      }
    }
  }

  // ── 3. Curriculum-level milestone ────────────────────────────────────────
  final totalUnits = _countTotalUnits(content, curriculum);
  if (completedUnits.length >= totalUnits && totalUnits > 0) {
    final allEntries = [...unitLevelEntries]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    milestones.add(
      MilestoneAchievement(
        type: 'curriculum_complete',
        level: MilestoneLevel.curriculum,
        curriculumId: curriculum,
        displayName: curriculumLabelTextFromRef(ref, curriculum: curriculum),
        achievedAt: allEntries.first.completedAt,
      ),
    );
  }

  return milestones;
}
