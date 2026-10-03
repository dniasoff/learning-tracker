// Parent push wire / session values (Story 4.7 / DNI-515).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';

const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';

Map<String, dynamic> _data([Map<String, dynamic> over = const {}]) => {
  'type': 'tutor_change',
  'owner_uid': 'owner-uid',
  'profile_id': _profile,
  'action_id': '01JTEST0000000000000000001',
  'entry_id': '01JTEST0000000000000000001',
  'kind': 'deadline',
  'tutor_name': 'Rav Cohen',
  'learner_name': 'Yehuda',
  ...over,
};

void main() {
  group('ParentPushMessage.tryParse', () {
    test('parses the trigger payload', () {
      final m = ParentPushMessage.tryParse(_data())!;
      expect(m.ownerUid, 'owner-uid');
      expect(m.profileId, _profile);
      expect(m.kind, ParentPushKind.deadline);
      expect(m.tutorName, 'Rav Cohen');
      expect(m.learnerName, 'Yehuda');
    });

    test('every trigger kind maps; an unknown kind is "other"', () {
      for (final k in [
        'deadline',
        'pace',
        'mainTrack',
        'mainTrackOrder',
        'mainTrackProgram',
        'mainTrackStudyDays',
      ]) {
        expect(ParentPushMessage.tryParse(_data({'kind': k}))!.kind.name, k);
      }
      expect(
        ParentPushMessage.tryParse(_data({'kind': 'other'}))!.kind,
        ParentPushKind.other,
      );
      expect(
        ParentPushMessage.tryParse(_data({'kind': 'brandNew'}))!.kind,
        ParentPushKind.other,
      );
    });

    test('other data messages and malformed payloads are ignored', () {
      expect(ParentPushMessage.tryParse(_data({'type': 'other'})), isNull);
      expect(ParentPushMessage.tryParse(_data({'owner_uid': ''})), isNull);
      expect(ParentPushMessage.tryParse(_data({'profile_id': null})), isNull);
      expect(ParentPushMessage.tryParse(_data({'action_id': 3})), isNull);
    });

    test('missing names parse as empty', () {
      final m = ParentPushMessage.tryParse(
        _data()
          ..remove('tutor_name')
          ..remove('learner_name'),
      )!;
      expect(m.tutorName, '');
      expect(m.learnerName, '');
    });
  });

  group('ParentPushTap', () {
    test('round-trips through the local-notification payload', () {
      const tap = ParentPushTap(ownerUid: 'owner-uid', profileId: _profile);
      expect(ParentPushTap.tryParsePayload(tap.toPayload()), tap);
      expect(ParentPushMessage.tryParse(_data())!.tap, tap);
    });

    test('foreign or malformed payloads are not parent push taps', () {
      expect(ParentPushTap.tryParsePayload(null), isNull);
      expect(ParentPushTap.tryParsePayload('daily_reminder:$_profile'), isNull);
      expect(ParentPushTap.tryParsePayload('parent_push:{not json'), isNull);
      expect(ParentPushTap.tryParsePayload('parent_push:[1]'), isNull);
      expect(ParentPushTap.tryParsePayload('parent_push:{"o":"x"}'), isNull);
    });

    test(
      'opens history only in the owning account, own session, same learner',
      () {
        const tap = ParentPushTap(ownerUid: 'owner-uid', profileId: _profile);
        expect(
          tap.opensHistory(
            currentOwnerUid: 'owner-uid',
            selectedProfileId: _profile,
            isTutoredSession: false,
          ),
          isTrue,
        );
        expect(
          tap.opensHistory(
            currentOwnerUid: 'other-uid',
            selectedProfileId: _profile,
            isTutoredSession: false,
          ),
          isFalse,
        );
        expect(
          tap.opensHistory(
            currentOwnerUid: 'owner-uid',
            selectedProfileId: 'another-profile',
            isTutoredSession: false,
          ),
          isFalse,
        );
        expect(
          tap.opensHistory(
            currentOwnerUid: 'owner-uid',
            selectedProfileId: _profile,
            isTutoredSession: true,
          ),
          isFalse,
        );
      },
    );
  });

  group('ParentPushSession', () {
    const session = ParentPushSession(
      accountId: 'acct-1',
      ownerUid: 'owner-uid',
      profileId: _profile,
    );

    test('encodes and decodes', () {
      expect(ParentPushSession.tryDecode(session.encode()), session);
      expect(ParentPushSession.tryDecode(null), isNull);
      expect(ParentPushSession.tryDecode('garbage'), isNull);
      expect(ParentPushSession.tryDecode('{"account_id":1}'), isNull);
    });

    test('allows only a push for its owner and learner', () {
      expect(session.allows(ParentPushMessage.tryParse(_data())!), isTrue);
      expect(
        session.allows(
          ParentPushMessage.tryParse(_data({'owner_uid': 'other'}))!,
        ),
        isFalse,
      );
      expect(
        session.allows(
          ParentPushMessage.tryParse(_data({'profile_id': 'other'}))!,
        ),
        isFalse,
      );
    });
  });
}
