import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';

/// Stability canary for [stableProfileHash] and the `*IdForProfile` helpers.
///
/// AD-24 made profile identity a ULID string, but Android notification IDs
/// must still be small ints — [stableProfileHash] is a hand-rolled FNV-1a
/// (deliberately not `String.hashCode`, which Dart does not guarantee is
/// stable across Dart/Flutter versions) that must produce the SAME id for
/// the SAME profileId on every run, forever: a scheduled notification's ID
/// is recomputed later purely to cancel it, with no persisted ULID→ID map
/// to fall back on. If this algorithm — or the block-size/offset constants
/// it feeds into — ever changes, every notification already scheduled on a
/// user's device becomes uncancellable. These pinned expected values exist
/// so that kind of change fails a test instead of shipping silently.
void main() {
  group('stableProfileHash — pinned canary values', () {
    test('a known ULID hashes to its pinned value', () {
      expect(stableProfileHash('01ARZ3NDEKTSV4RRFFQ69G5FAV'), 1543523712);
    });

    test('a second known ULID hashes to a different pinned value', () {
      expect(stableProfileHash('01BX5ZZKBKACTAV9WEVGEMMVRZ'), 2346214123);
    });

    test('the empty string hashes to the FNV-1a basis', () {
      expect(stableProfileHash(''), 0x811c9dc5);
    });

    test('is deterministic across repeated calls', () {
      const id = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
      expect(stableProfileHash(id), stableProfileHash(id));
    });
  });

  group('*IdForProfile — pinned canary values', () {
    const id = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

    test('dailyReminderIdForProfile is pinned', () {
      expect(dailyReminderIdForProfile(id), 1523713000);
    });

    test('streakAlertIdForProfile is pinned', () {
      expect(streakAlertIdForProfile(id), 1523713001);
    });

    test('batchBaseIdForProfile is pinned', () {
      expect(batchBaseIdForProfile(id), 1523713010);
    });

    test('every id for a profile stays within Android\'s 32-bit range', () {
      // batchBaseIdForProfile + 13 is the largest id any single profile
      // produces (the 14-day rolling batch, offset 10..23).
      expect(batchBaseIdForProfile(id) + 13, lessThan(1 << 31));
    });

    test('block number is never 0 for any hash outcome', () {
      // Regression guard for the "+1" in _blockForProfile: a hash that
      // happens to be an exact multiple of _maxBlocks must not produce
      // block 0 (reserved).
      for (final probe in ['', 'a', 'zzzzzzzzzzzzzzzzzzzzzzzzzz']) {
        expect(dailyReminderIdForProfile(probe), greaterThanOrEqualTo(1000));
      }
    });
  });
}
