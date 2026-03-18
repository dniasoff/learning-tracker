import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journey_providers.g.dart';

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

/// Stub provider for learning ledger entries.
///
/// TODO(DNI-124): Replace with real learningLedgerProvider once the Lifetime
/// Learning Ledger story is merged. Currently returns an empty list.
@riverpod
Future<List<LedgerEntry>> learningLedger(Ref ref, int profileId) async {
  // Stub: no ledger data until DNI-124 is merged
  return [];
}

/// Computes the full JourneyViewModel for a given profile.
@riverpod
Future<JourneyViewModel> journeyViewModel(Ref ref, int profileId) async {
  final ledgerEntries = await ref.watch(learningLedgerProvider(profileId).future);
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
    final completions = entriesForCurriculum.map((e) => UnitCompletion(
      unitIdentifier: e.unitIdentifier,
      unitType: e.unitType,
      displayNameHe: e.unitDisplayNameHe,
      displayNameEn: e.unitDisplayNameEn,
      trackType: TrackType.fromStorageKey(e.trackType),
      completedAt: e.completedAt,
      completionNumber: e.completionNumber,
      isManual: e.isManual,
    )).toList();

    // Count unique units
    final uniqueUnits = entriesForCurriculum
        .map((e) => e.unitIdentifier)
        .toSet();

    // Detect milestones
    final milestones = _detectMilestones(
      entriesForCurriculum,
      content,
      curriculum,
    );

    totalCompletions += completions.length;
    allUniqueUnits.addAll(uniqueUnits);

    if (completions.isNotEmpty || totalUnits > 0) {
      curricula.add(CurriculumJourney(
        curriculumId: curriculum,
        completions: completions,
        uniqueUnitsCompleted: uniqueUnits.length,
        totalUnitsAvailable: totalUnits,
        milestones: milestones,
      ));
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
  List<LedgerEntry> entries,
  List<ContentItem> content,
  CurriculumId curriculum,
) {
  final milestones = <MilestoneAchievement>[];
  if (entries.isEmpty) return milestones;

  final completedUnits = entries.map((e) => e.unitIdentifier).toSet();

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
        final sederCompletions = entries
            .where((e) => entry.value.contains(e.unitIdentifier))
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        if (sederCompletions.isNotEmpty) {
          milestones.add(MilestoneAchievement(
            type: 'seder_complete',
            displayName: entry.key,
            achievedAt: sederCompletions.first.completedAt,
          ));
        }
      }
    }
  }

  // Check curriculum-level milestone (all units completed)
  final totalUnits = _countTotalUnits(content, curriculum);
  if (completedUnits.length >= totalUnits && totalUnits > 0) {
    final allEntries = [...entries]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    milestones.add(MilestoneAchievement(
      type: 'curriculum_complete',
      displayName: curriculum.displayNameEn,
      achievedAt: allEntries.first.completedAt,
    ));
  }

  return milestones;
}

/// Temporary stub model for ledger entries until DNI-124 is merged.
///
/// TODO(DNI-124): Remove this class and use the real LearningLedger model.
class LedgerEntry {
  const LedgerEntry({
    required this.curriculumId,
    required this.unitType,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    required this.completedAt,
    required this.completionNumber,
    required this.isManual,
  });

  final String curriculumId;
  final String unitType;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final DateTime completedAt;
  final int completionNumber;
  final bool isManual;
}
