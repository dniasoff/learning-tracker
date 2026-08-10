/// Unit tests for [TutorGrantMerger] — the deliberate no-op merger for the
/// `tutor_grant` entity kind (tutor grants live only in Firestore; there is
/// no local SQLite table for them). See
/// lib/core/sync/merge/tutor_grant_merger.dart for the rationale: without a
/// wired merger for this kind, [MergeRouter] would halt the pull pipeline
/// instead of continuing to the next page.
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/tutor_grant_roundtrip_test
/// .dart's codec.encode() → merger integration case into this file; that
/// file's codec-only encode/decode coverage lives in the mirrored
/// test/core/sync/codec/tutor_grant_codec_test.dart instead.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/tutor_grant_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/tutor_grant_merger.dart';

void main() {
  group('TutorGrantMerger', () {
    const merger = TutorGrantMerger();

    test('kind is "tutor_grant"', () {
      expect(merger.kind, EntityKind.tutorGrant);
    });

    test('merger.merge() accepts a codec.encode() payload without throwing '
        '(deliberate no-op — grants are never stored locally)', () async {
      const codec = TutorGrantCodec();
      final payload = codec.encode(
        TutorGrantRow(
          grantId: 'grant-01JBVZ0000TESTGRANT0000AB',
          tutorUid: 'tutor-uid-1',
          parentUid: 'parent-uid-1',
          childProfileId: 7,
          state: 'active',
          createdAt: DateTime.utc(2026, 6, 1, 8, 0, 0),
          updatedAt: DateTime.utc(2026, 6, 18, 10, 0, 0),
          tutorEmail: 'tutor@example.com',
        ),
      );

      await expectLater(
        merger.merge(profileId: 1, rows: [payload]),
        completes,
        reason:
            'TutorGrantMerger exists so MergeRouter can return '
            'continueNext for the tutor_grant kind instead of halting '
            'the pull pipeline — it must never throw on a well-formed '
            'codec payload, even though it stores nothing locally.',
      );
    });

    test(
      'merge() completes without throwing for a non-empty rows page',
      () async {
        await expectLater(
          merger.merge(
            profileId: 1,
            rows: [
              {
                'grant_id': 'g1',
                'tutor_uid': 'tutor-1',
                'parent_uid': 'parent-1',
                'child_profile_id': 1,
                'state': 'active',
              },
            ],
          ),
          completes,
        );
      },
    );

    test('merge() completes without throwing for an empty rows page', () async {
      await expectLater(merger.merge(profileId: 1, rows: []), completes);
    });

    test('merge() is a true no-op — it never touches local storage (no '
        'exception is possible from a missing DB/store because none is '
        'injected into the merger)', () {
      // TutorGrantMerger takes no MergeStore / DB dependency at all — its
      // constructor is const with zero fields. This is itself the
      // regression guard: if a future change adds a dependency here, the
      // const constructor call below stops compiling, forcing this test
      // (and its doc comment) to be revisited.
      const another = TutorGrantMerger();
      expect(another.kind, EntityKind.tutorGrant);
    });
  });
}
