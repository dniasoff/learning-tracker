import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'scheduler_content_repository.freezed.dart';

/// Scheduler-local content item representation.
///
/// Level fields are included so the engine can group leaves by their
/// coarse parent (e.g. all mishnas under one perek) when a goal sets the
/// pace in coarse units (`paceGranularity == 'perek'` etc.). Only the levels
/// the source data populates are non-null; for 3-level books `level4` is
/// null.
@freezed
abstract class SchedulerContentItem with _$SchedulerContentItem {
  const SchedulerContentItem._();

  const factory SchedulerContentItem({
    required String sefariaRef,
    required int sortOrder,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) = _SchedulerContentItem;

  /// The coarse-unit key — all level values up to (but excluding) the
  /// leaf. For a 4-level item (e.g. Mishnayos `Seder|Masechta|Perek|Mishna`)
  /// returns `level1|level2|level3`. For a 3-level item (e.g. Chumash
  /// `Sefer|Perek|Pasuk`) returns `level1|level2`. Returns `null` if
  /// the item has no parent levels.
  String? get coarseUnitKey {
    if (level4 != null) return '$level1|$level2|$level3';
    if (level3 != null) return '$level1|$level2';
    if (level2 != null) return level1;
    return null;
  }
}

/// Abstract repository for content items consumed by the scheduler.
///
/// Decouples the scheduler from the content_browsing feature per P6.
abstract class SchedulerContentRepository {
  /// Get all leaf content items for a curriculum, ordered by sortOrder.
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId curriculumId);
}
