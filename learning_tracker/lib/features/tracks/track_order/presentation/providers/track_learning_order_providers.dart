import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

final trackLearningOrderRepositoryProvider =
    Provider<TrackLearningOrderRepository>((ref) {
      return FirestoreTrackLearningOrderRepositoryAdapter(ref: ref);
    });

// AUD-tracks-15 (SM-8): TrackLearningOrderRepositoryImpl no longer depends
// on ContentRepository — it only talks to Firestore. The content-fetch +
// index-build orchestration lives here instead: each provider resolves the
// curriculum's content list via ContentRepository, then passes it into the
// repository call.

final trackSedarimOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final allItems = await ref
          .watch(contentRepositoryProvider)
          .getContentForCurriculum(curriculumId);
      return ref
          .watch(trackLearningOrderRepositoryProvider)
          .getSedarimOrder(curriculumId, allItems);
    });

final trackMasechtosOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final allItems = await ref
          .watch(contentRepositoryProvider)
          .getContentForCurriculum(curriculumId);
      return ref
          .watch(trackLearningOrderRepositoryProvider)
          .getMasechtosOrder(curriculumId, allItems);
    });
