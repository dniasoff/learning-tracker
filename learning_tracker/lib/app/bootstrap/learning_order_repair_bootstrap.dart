import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';

/// Sweeps every [CurriculumId]'s §10.1 `learningOrderVersion` guard through
/// [LearningOrderRepository.repairStaleOrderVersion] once per app start
/// (AUD-tracks-06 REGRESSION bounce).
///
/// [LearningOrderRepositoryImpl.getOrder] is a deliberately pure read
/// (SM-2) — the version-mismatch re-amnesty write that used to live there
/// as a side effect was extracted into the explicit, idempotent
/// [LearningOrderRepository.repairStaleOrderVersion]. Without a caller for
/// that method, a stale guard left behind by a content reseed was never
/// repaired and pre-reseed overdue items were never re-amnestied — this
/// sweep is that caller, invoked once from [bootstrap] as a fire-and-forget
/// task so it never delays `runApp` (matching how content-DB
/// seeding/reseeding itself is deferred — see [contentDbPathProvider]).
///
/// Awaits [contentVersionProvider] first so the repository it reads
/// afterwards is built against the *resolved* seed version rather than
/// [learningOrderRepositoryProvider]'s synchronous fallback default of 1
/// (which would make every row look "not stale" until something else
/// happens to rebuild the repository provider).
///
/// Non-fatal: a failure here (including the content DB never finishing
/// extraction) is logged and swallowed so it can never prevent app
/// startup — an unrepaired guard simply retries on the next launch.
Future<void> repairStaleLearningOrders({
  required ProviderContainer container,
  required AppLogger log,
}) async {
  try {
    await container.read(contentVersionProvider.future);
    final repository = container.read(learningOrderRepositoryProvider);
    for (final curriculumId in CurriculumId.all) {
      await repository.repairStaleOrderVersion(curriculumId);
    }
  } catch (e, stack) {
    log.error(
      event: 'learning_order_repair_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
