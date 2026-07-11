/// Unit tests for lib/core/sync/merge/merge_rules.dart's
/// [remoteIsNewer] sync-engine predicate.
///
/// AUD-core-sync-37: lwwMerge / mergeForwardMaxInt / mergeForwardMaxDate /
/// mergeForwardUnion / MergeResult were deleted from merge_rules.dart — a
/// repo-wide grep showed no production merger called them (the real LWW
/// gate for every merger but StudyDayConfigMerger is
/// DriftMergeStore.remoteIsNewer). Their tests are removed with them.
/// remoteIsNewer stays covered below because StudyDayConfigMerger still
/// calls it in production (pending AUD-core-sync-03).
///
/// Note: a same-named but distinct `merge_rules.dart` exists at
/// lib/features/sync/domain/merge_rules.dart with its own mirrored test at
/// test/features/sync/domain/merge_rules_test.dart — that file is NOT a
/// mirror of this one (AG-4 duplicate-name candidate, out of scope for this
/// finding; noted as a follow-up).
///
/// AG-5 (AUD-app-05): this file is the mirrored test AG-5's checker
/// requires for lib/core/sync/merge/merge_rules.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

void main() {
  group('remoteIsNewer (sync engine predicate)', () {
    test('strictly newer remote → true', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 1, 1),
          remoteUpdatedAt: DateTime.utc(2026, 2, 1),
        ),
        isTrue,
      );
    });

    test('equal timestamps → false (no flapping)', () {
      final ts = DateTime.utc(2026, 1, 1);
      expect(remoteIsNewer(localUpdatedAt: ts, remoteUpdatedAt: ts), isFalse);
    });

    test('older remote → false', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 3, 1),
          remoteUpdatedAt: DateTime.utc(2026, 1, 1),
        ),
        isFalse,
      );
    });

    test('null local → remote always wins', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: null,
          remoteUpdatedAt: DateTime.utc(2026, 1, 1),
        ),
        isTrue,
      );
    });

    test('null remote → never wins', () {
      expect(
        remoteIsNewer(
          localUpdatedAt: DateTime.utc(2026, 1, 1),
          remoteUpdatedAt: null,
        ),
        isFalse,
      );
    });
  });
}
