import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/track_learning_order/data/repositories/track_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/track_learning_order/domain/repositories/track_learning_order_repository.dart';

final trackLearningOrderRepositoryProvider =
    Provider<TrackLearningOrderRepository>((ref) {
      return TrackLearningOrderRepositoryImpl(
        database: ref.watch(userDatabaseProvider),
        contentRepository: ref.watch(contentRepositoryProvider),
      );
    });

typedef _TrackCurriculumArgs = ({int trackId, CurriculumId curriculumId});

final trackSedarimOrderProvider = FutureProvider.family<
    List<LearningOrderItem>,
    _TrackCurriculumArgs>((ref, args) {
  return ref
      .watch(trackLearningOrderRepositoryProvider)
      .getSedarimOrder(args.trackId, args.curriculumId);
});

final trackMasechtosOrderProvider = FutureProvider.family<
    List<LearningOrderItem>,
    _TrackCurriculumArgs>((ref, args) {
  return ref
      .watch(trackLearningOrderRepositoryProvider)
      .getMasechtosOrder(args.trackId, args.curriculumId);
});
