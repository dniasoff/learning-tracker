/// Regression test for AUD-core-sync-05.
///
/// [EntityCodec.decode] documents a hard contract: "Returns null when
/// required fields are missing or malformed — the merger must skip
/// malformed rows rather than crash." [TrackCodec.decode] and
/// [GoalCodec.decode] violated that contract for their numeric fields by
/// using a bare `as int?` / `as num?` cast instead of
/// [FirestoreCodec.parseInt] / [FirestoreCodec.parseDouble]. A bare cast
/// throws a [TypeError] when the field arrives as anything but exactly the
/// expected type (e.g. a `String` from a hand-edited doc, an import script,
/// or a legacy document) — it does NOT return null on a merely-malformed
/// value the way the rest of the codec does.
///
/// [TrackConfigMerger.merge] and [GoalMerger.merge] call `decode()` inside a
/// `for` loop with no try/catch, and [MergeRouter.dispatch] awaits
/// `merger.merge()` with no try/catch either — so a single malformed numeric
/// field throws out of the entire multi-collection pull-on-launch pass
/// instead of being skipped as one bad row.
@Tags(['unit', 'sync'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';

void main() {
  group('TrackCodec.decode — malformed numeric fields (AUD-core-sync-05)', () {
    const codec = TrackCodec();

    test('string-typed profile_id/track_id decode instead of throwing', () {
      final row = codec.decode({
        'profile_id': '5',
        'track_id': '7',
        'curriculum_id': 'x',
        'activated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(row, isNotNull);
      expect(row!.profileId, 5);
      expect(row.trackId, 7);
    });

    test('int-typed profile_id/track_id still decode (no regression on the '
        'happy path)', () {
      final row = codec.decode({
        'profile_id': 5,
        'track_id': 7,
        'curriculum_id': 'x',
        'activated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(row, isNotNull);
      expect(row!.profileId, 5);
      expect(row.trackId, 7);
    });

    test('a genuinely unparsable profile_id (non-numeric string) decodes to '
        'the documented 0 fallback rather than throwing', () {
      final row = codec.decode({
        'profile_id': 'not-a-number',
        'track_id': 7,
        'curriculum_id': 'x',
        'activated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(row, isNotNull);
      expect(row!.profileId, 0);
    });
  });

  group('GoalCodec.decode — malformed target_percent (AUD-core-sync-05)', () {
    const codec = GoalCodec();

    Map<String, dynamic> baseRow({required Object? targetPercent}) => {
      'firestore_id': 'g1',
      'profile_id': 1,
      'curriculum_id': 'bavli',
      'updated_at': '2026-06-18T10:00:00.000Z',
      'created_at': '2026-01-01T00:00:00.000Z',
      'target_percent': targetPercent,
    };

    test('string-typed target_percent decodes to the parsed double instead of '
        'throwing', () {
      final row = codec.decode(baseRow(targetPercent: '55'));

      expect(row, isNotNull);
      expect(row!.targetPercent, 55.0);
    });

    test('num-typed target_percent still decodes (no regression on the happy '
        'path)', () {
      final row = codec.decode(baseRow(targetPercent: 55));

      expect(row, isNotNull);
      expect(row!.targetPercent, 55.0);
    });

    test('missing target_percent falls back to the 100.0 default', () {
      final row = codec.decode(baseRow(targetPercent: null));

      expect(row, isNotNull);
      expect(row!.targetPercent, 100.0);
    });
  });
}
