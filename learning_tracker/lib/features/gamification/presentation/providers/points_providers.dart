import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';

/// Provider for the PointsService over the AD-50 filtered ledger
/// ([EnginePointsReader], DNI-480).
final pointsServiceProvider = Provider<PointsService>((ref) {
  final reader = EnginePointsReader(ref: ref);
  return PointsService(balanceReader: reader, earnedReader: reader);
});

/// Global debitable points balance: the AD-50 filtered ledger sum.
///
/// **Not a live ledger stream** — `firestore.rules` caps every
/// `points_ledger` query at `limit <= 500` (SR-4), so there is no
/// single-listener watch of the whole ledger. It re-reads whenever the
/// engine's earning set changes (a capture or a void on any device,
/// [activeEarningEventIdsProvider]), whenever [completionCommittedProvider]
/// fires, and on explicit invalidation after a redemption or adjustment.
final globalPointsProvider = FutureProvider<int>((ref) async {
  ref.watch<int>(completionCommittedProvider);
  return (await watchActivePointsTotals(ref)).balance;
});

/// Per-curriculum breakdown of counted awards.
///
/// DG-BRKD-01: re-evaluated after a completion is committed and whenever
/// the engine's earning set changes, so the breakdown chips in
/// `PointsDisplayWidget` stay live.
final curriculumBreakdownProvider = FutureProvider<Map<CurriculumId, int>>((
  ref,
) async {
  ref.watch<int>(completionCommittedProvider);
  await ref.watch(activeEarningEventIdsProvider.future);
  return ref.watch(pointsServiceProvider).getCurriculumBreakdown();
});
