import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';

/// Firestore-backed write seam for manual parent points adjustments
/// (`ParentSettingsScreen`'s "Adjust Points" dialog).
///
/// Mirrors [FirestorePointsBalanceReaderAdapter]'s resolve/throw pattern —
/// see that class's doc comment. A parent adjustment is an explicit,
/// deliberate user action with no natural "did nothing" outcome, so a
/// not-ready backend throws rather than silently dropping the write.
class FirestorePointsLedgerWriteAdapter {
  FirestorePointsLedgerWriteAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Appends a `parent_add`/`parent_deduct` points-ledger entry for
  /// [delta] (positive to add, negative to deduct — matches
  /// `PointsLedgerEntry.entryKind`'s Drift-era vocabulary).
  Future<void> appendParentAdjustment({
    required int delta,
    String? note,
  }) async {
    final repo = await _ref.read(
      firestorePointsLedgerRepositoryProvider.future,
    );
    if (repo == null) {
      throw StateError(
        'FirestorePointsLedgerWriteAdapter.appendParentAdjustment: '
        'firestorePointsLedgerRepositoryProvider resolved to null (no '
        'active account, or no active learner profile, yet) — refusing to '
        'silently drop a parent-entered points adjustment of $delta.',
      );
    }
    await repo.append(
      entryKind: delta >= 0 ? 'parent_add' : 'parent_deduct',
      delta: delta,
      createdAt: DateTimeFactory.nowUtc(),
      note: note,
    );
  }
}
