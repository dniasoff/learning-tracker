/// Round-trip test: the canonical write serializer (TutorGrantCodec.encode)
/// must produce a payload that TutorGrantMerger accepts without throwing.
///
/// AUD-core-sync-16: tutor_grant_codec.dart had zero direct test coverage.
/// Every other non-trivial codec in this batch has a
/// `test/sync/merge/*_roundtrip_test.dart` sibling — this file closes that
/// gap for tutor_grants, mirroring the existing pattern as closely as the
/// entity allows.
///
/// Unlike every other merger in this batch, [TutorGrantMerger] is a
/// deliberate no-op at the DB layer (see its own doc comment: "Tutor grants
/// are not stored in the local SQLite database; they are always read live
/// from Firestore."). The live UI path reads grants via
/// `FirestoreTutorGrantRepository` / `TutorGrant.fromDoc`, never this codec
/// (confirmed: `TutorGrantCodec()` has zero call sites outside its own
/// definition and this test file). This codec+merger pair exists only so
/// [MergeRouter] can return `continueNext` for the `tutor_grant` kind
/// instead of halting the pull pipeline — the invariant this test locks is
/// "encode() → merge() never throws", not "a row lands somewhere".
@Tags(['unit', 'sync'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/tutor_grant_codec.dart';
import 'package:learning_tracker/core/sync/merge/tutor_grant_merger.dart';

const _codec = TutorGrantCodec();
const _merger = TutorGrantMerger();

const _profileId = 1;
const _grantId = 'grant-01JBVZ0000TESTGRANT0000AB';
const _tutorUid = 'tutor-uid-1';
const _parentUid = 'parent-uid-1';
const _childProfileId = 7;
const _state = 'active';
final _createdAt = DateTime.utc(2026, 6, 1, 8, 0, 0);
final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
const _tutorEmail = 'tutor@example.com';

TutorGrantRow _row({DateTime? revokedAt}) => TutorGrantRow(
  grantId: _grantId,
  tutorUid: _tutorUid,
  parentUid: _parentUid,
  childProfileId: _childProfileId,
  state: _state,
  createdAt: _createdAt,
  updatedAt: _updatedAt,
  tutorEmail: _tutorEmail,
  revokedAt: revokedAt,
);

void main() {
  group('tutor_grants — codec.encode() → merger round-trip', () {
    test(
      'codec.encode() payload carries every field the wire schema expects',
      () {
        final payload = _codec.encode(_row());

        expect(payload['grant_id'], _grantId);
        expect(payload['tutor_uid'], _tutorUid);
        expect(payload['parent_uid'], _parentUid);
        expect(payload['child_profile_id'], _childProfileId);
        expect(payload['state'], _state);
        expect(payload.containsKey('created_at'), isTrue);
        expect(payload.containsKey('updated_at'), isTrue);
        expect(payload['tutor_email'], _tutorEmail);
        expect(
          payload.containsKey('revoked_at'),
          isFalse,
          reason: 'revoked_at is omitted when null (active grant)',
        );
      },
    );

    test('created_at/updated_at are pushed via FirestoreCodec.encodeDateTime '
        '(always UTC, always Z-suffixed)', () {
      final payload = _codec.encode(_row());

      expect(payload['created_at'], endsWith('Z'));
      expect(payload['updated_at'], endsWith('Z'));
    });

    test('merger.merge() accepts the codec payload without throwing '
        '(deliberate no-op — grants are never stored locally)', () async {
      final payload = _codec.encode(_row());

      await expectLater(
        _merger.merge(profileId: _profileId, rows: [payload]),
        completes,
        reason:
            'TutorGrantMerger exists so MergeRouter can return '
            'continueNext for the tutor_grant kind instead of halting '
            'the pull pipeline — it must never throw on a well-formed '
            'codec payload, even though it stores nothing locally.',
      );
    });

    test('merger.kind matches EntityKind.tutorGrant', () {
      expect(_merger.kind, _codec.kind);
    });

    test('codec round-trips through encode → decode', () {
      final row = _row(revokedAt: DateTime.utc(2026, 6, 20));
      final payload = _codec.encode(row);
      final decoded = _codec.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.grantId, _grantId);
      expect(decoded.tutorUid, _tutorUid);
      expect(decoded.parentUid, _parentUid);
      expect(decoded.childProfileId, _childProfileId);
      expect(decoded.state, _state);
      expect(decoded.createdAt.toUtc(), _createdAt);
      expect(decoded.updatedAt.toUtc(), _updatedAt);
      expect(decoded.tutorEmail, _tutorEmail);
      expect(decoded.revokedAt?.toUtc(), DateTime.utc(2026, 6, 20));
    });

    test(
      'null-guard: missing required field (state) causes decode to return null',
      () {
        final payload = _codec.encode(_row());
        final broken = Map<String, dynamic>.from(payload)..remove('state');

        expect(_codec.decode(broken), isNull);
      },
    );
  });
}
