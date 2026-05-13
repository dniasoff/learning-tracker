import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/learning/completion_writer_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
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

    // Detect milestones
    final milestones = _detectMilestones(
      ref,
      entriesForCurriculum,
      content,
      curriculum,
    );

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
  final unitLevelEntries = entries
      .where((e) => e.entryScope == 'masechta' || e.entryScope == 'sefer')
      .toList();
  final completedUnits = unitLevelEntries.map((e) => e.unitIdentifier).toSet();

  // Check seder-level milestones (all masechtos in a seder completed)
  if (curriculum != CurriculumId.mussar) {
    final sederGroups = <String, Set<String>>{};
    for (final item in content) {
      if (item.level2 != null) {
        sederGroups.putIfAbsent(item.level1, () => {}).add(item.level2!);
      }
    }
    for (final entry in sederGroups.entries) {
      if (entry.value.every((unit) => completedUnits.contains(unit))) {
        // Find the latest completion date for this seder
        final sederCompletions =
            unitLevelEntries
                .where((e) => entry.value.contains(e.unitIdentifier))
                .toList()
              ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        if (sederCompletions.isNotEmpty) {
          milestones.add(
            MilestoneAchievement(
              type: 'seder_complete',
              displayName: entry.key,
              achievedAt: sederCompletions.first.completedAt,
            ),
          );
        }
      }
    }
  }

  // Check curriculum-level milestone (all units completed)
  final totalUnits = _countTotalUnits(content, curriculum);
  if (completedUnits.length >= totalUnits && totalUnits > 0) {
    final allEntries = [...unitLevelEntries]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    milestones.add(
      MilestoneAchievement(
        type: 'curriculum_complete',
        displayName: curriculumLabelTextFromRef(ref, curriculum: curriculum),
        achievedAt: allEntries.first.completedAt,
      ),
    );
  }

  return milestones;
}
