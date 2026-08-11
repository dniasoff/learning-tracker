import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';

/// Firestore-backed [PointsBalanceReader] — the wave plan's blocker 4:
/// declared, never implemented anywhere in `lib/`. Resolves
/// `firestorePointsLedgerRepositoryProvider` and delegates to
/// `FirestorePointsLedgerRepository.getBalance()`, which already sums the
/// full ledger client-side (not just a paginated "recent" window) and
/// clamps to `[0, 1 << 30]`.
///
/// D-E: throws rather than returning 0 when the backend is not ready — the
/// debitable balance is achievement/spend-economy data, and a fabricated
/// zero here would look like "you have no points" to a child who does.
class FirestorePointsBalanceReaderAdapter implements PointsBalanceReader {
  FirestorePointsBalanceReaderAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<int> getBalance() async {
    final repo = await _ref.read(
      firestorePointsLedgerRepositoryProvider.future,
    );
    if (repo == null) {
      throw StateError(
        'FirestorePointsBalanceReaderAdapter.getBalance: '
        'firestorePointsLedgerRepositoryProvider resolved to null (no '
        'active account, or no active learner profile, yet) — refusing to '
        'report a balance of 0 when the true balance could not be read.',
      );
    }
    return repo.getBalance();
  }
}
