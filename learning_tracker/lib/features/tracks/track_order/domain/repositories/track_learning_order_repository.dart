import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

abstract class TrackLearningOrderRepository {
  /// Returns ordered sedarim (level1 containers) for the track.
  /// Falls back to canonical sort_order when no custom order is saved.
  Future<List<LearningOrderItem>> getSedarimOrder(
    int trackId,
    CurriculumId curriculumId,
  );

  /// Returns ordered masechtos (level2 containers) for the track.
  /// Falls back to canonical sort_order when no custom order is saved.
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    CurriculumId curriculumId,
  );

  Future<void> saveSedarimOrder(int trackId, List<LearningOrderItem> items);
  Future<void> saveMasechtosOrder(int trackId, List<LearningOrderItem> items);

  /// Deletes all custom order rows for the track (resets to canonical).
  Future<void> resetToDefault(int trackId);
}
