import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

// AUD-core-sync-37: lwwMerge / mergeForwardMaxInt / mergeForwardMaxDate /
// mergeForwardUnion / MergeResult were deleted from merge_rules.dart — a
// repo-wide grep showed no production merger called them (the real LWW
// gate for every merger but StudyDayConfigMerger is
// DriftMergeStore.remoteIsNewer). Their tests are removed with them.
// remoteIsNewer stays covered below because StudyDayConfigMerger still
// calls it in production (pending AUD-core-sync-03).
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
