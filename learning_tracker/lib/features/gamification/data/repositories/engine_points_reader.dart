/// The AD-50 points readers (DNI-480, Retirement Inventory R7): the
/// balance, lifetime-earned and per-curriculum readers all sum the active
/// learner's points ledger through `FirestorePointsLedgerRepository
/// .getTotals`, counting a `pts_{eventId}` row only while the engine says
/// its event earns (`LearnerState.earningEventIds`).
///
/// They replace the old-store `FirestorePointsBalanceReaderAdapter` and
/// `FirestorePointsLifetimeEarnedReaderAdapter`, which summed every row.
/// A void on any device changes the engine's earning set, so every reader
/// that watches [activeEarningEventIdsProvider] re-reads and both totals
/// fall; no reversal row is ever written.
///
/// D-E: a reader never reports a fabricated zero. With no active learner,
/// no ready ledger repository, or a failed learner state, it throws
/// [PointsNotReadyException] (or forwards the state's error); while the
/// state loads it stays pending.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

/// Thrown when the points of the active learner cannot be read yet: no
/// active learner, or no ready points-ledger repository.
///
/// A [StateError], like the adapters it replaces: Riverpod's default retry
/// skips errors, so a reader fails at once instead of backing off.
final class PointsNotReadyException extends StateError {
  /// Creates the error; [reason] names what was missing.
  PointsNotReadyException(String reason)
    : super(
        '$reason — refusing to report points as 0 when the true value could '
        'not be read.',
      );
}

/// The active learner's state from a provider body: the state, its error,
/// or a pending future while it loads (the watching provider rebuilds when
/// it resolves).
Future<LearnerState> _watchState(Ref ref) {
  final value = ref.watch(activeLearnerStateProvider);
  if (value.hasError) return Future.error(value.error!, value.stackTrace);
  if (value.hasValue) {
    final state = value.value;
    if (state == null) {
      return Future.error(PointsNotReadyException('no active learner'));
    }
    return Future.value(state);
  }
  return Completer<LearnerState>().future;
}

/// The active learner's AD-50 earning set (`LearnerState.earningEventIds`),
/// re-emitted whenever the engine recomputes (a capture or a void on any
/// device). Points readers watch it so they re-read on change.
///
/// Kept alive: the points services read it with `ref.read` outside a
/// provider build, which an auto-disposed provider would not survive.
final activeEarningEventIdsProvider = FutureProvider<Set<String>>(
  (ref) async => (await _watchState(ref)).earningEventIds,
  retry: (retryCount, error) => null,
);

/// The counted learn events of the active learner by id, for joining an
/// earning ledger row to its curriculum.
final activeCountedLearnsProvider = FutureProvider<Map<String, String?>>(
  (ref) async => {
    for (final e in (await _watchState(ref)).countedLearns)
      e.id: e.curriculumId,
  },
  retry: (retryCount, error) => null,
);

/// The active learner's ledger repository; a missing one is not ready.
///
/// Read before the earning set, so a not-ready backend fails at once
/// instead of waiting on a learner state that cannot load.
Future<FirestorePointsLedgerRepository> _ledger(Ref ref) async {
  final repo = await ref.read(firestorePointsLedgerRepositoryProvider.future);
  if (repo == null) {
    throw PointsNotReadyException(
      'firestorePointsLedgerRepositoryProvider resolved to null (no active '
      'account, or no active learner profile, yet)',
    );
  }
  return repo;
}

/// The active learner's AD-50 filtered totals from inside a provider body:
/// the provider watches the earning set, so a capture or a void on any
/// device re-reads the ledger.
///
/// The earning set is awaited only when the ledger holds event rows.
Future<PointsTotals> watchActivePointsTotals(Ref ref) async {
  final earning = ref.watch(activeEarningEventIdsProvider.future)..ignore();
  final repo = await _ledger(ref);
  return repo.resolveTotals(() => earning);
}

/// The [PointsBalanceReader], [PointsLifetimeEarnedReader] and
/// [EarnedPointsReader] of the active learner, over the AD-50 filtered
/// ledger. Each call reads the ledger afresh.
final class EnginePointsReader
    implements
        PointsBalanceReader,
        PointsLifetimeEarnedReader,
        EarnedPointsReader {
  /// Creates the reader over [ref].
  EnginePointsReader({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// The filtered balance and lifetime earned.
  Future<PointsTotals> getTotals() async {
    final repo = await _ledger(_ref);
    return repo.resolveTotals(
      () => _ref.read(activeEarningEventIdsProvider.future),
    );
  }

  @override
  Future<int> getBalance() async => (await getTotals()).balance;

  @override
  Future<int> getLifetimeEarned() async => (await getTotals()).lifetimeEarned;

  @override
  Future<List<EarnedPoints>> getEarnedPoints() async {
    final repo = await _ledger(_ref);
    final ledger = await repo.getLedger();
    if (!ledger.any((e) => e.eventId != null)) return const [];
    final earning = await _ref.read(activeEarningEventIdsProvider.future);
    final curricula = await _ref.read(activeCountedLearnsProvider.future);
    final seen = <String>{};
    return [
      for (final entry in ledger)
        if (entry.eventId case final eventId?)
          if (earning.contains(eventId) && seen.add(entry.ulid))
            if (CurriculumId.fromStorageKey(curricula[eventId] ?? '')
                case final curriculum?)
              EarnedPoints(
                eventId: eventId,
                curriculumId: curriculum,
                points: entry.delta,
              ),
    ];
  }
}
