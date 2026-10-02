/// The progress feature's read of AD-50 points awards (DNI-474): the
/// `completion` rows of the active learner's points ledger that name their
/// learn event, as [PointsLedgerRow]s. The recent-activity points chart
/// keeps only the rows whose event the engine says earns
/// (`LearnerState.earningEventIds`), bucketed by that event's day.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';

/// The active learner's event-linked points awards; empty while no learner
/// is active.
final progressPointsAwardsProvider =
    FutureProvider.autoDispose<List<PointsLedgerRow>>((ref) async {
      final repository = await ref.watch(
        firestorePointsLedgerRepositoryProvider.future,
      );
      if (repository == null) return const [];
      final entries = await repository.getLedger();
      return [
        for (final e in entries)
          if (e.entryKind == 'completion' && e.eventId != null)
            PointsLedgerRow(id: e.ulid, amount: e.delta, eventId: e.eventId),
      ];
    });
