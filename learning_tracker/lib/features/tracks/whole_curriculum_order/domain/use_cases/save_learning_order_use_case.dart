import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';

/// Saves a reordered list of items for the given curriculum.
///
/// Encapsulates the parent-control guard and delegates the actual persistence
/// + sync push to [LearningOrderRepository.saveOrder], keeping the repository
/// focused on data access only.
///
/// Throws [ParentControlException] when [isChildRestricted] is true.
class SaveLearningOrderUseCase {
  const SaveLearningOrderUseCase({required LearningOrderRepository repository})
    : _repository = repository;

  final LearningOrderRepository _repository;

  /// Saves [items] as the custom learning order for [curriculumId].
  ///
  /// Set [isChildRestricted] to `true` when the calling profile is a child
  /// whose parent has locked the ordering — the use case will throw
  /// [ParentControlException] before touching storage.
  Future<void> call(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) {
    return _repository.saveOrder(
      curriculumId,
      items,
      isChildRestricted: isChildRestricted,
    );
  }
}
