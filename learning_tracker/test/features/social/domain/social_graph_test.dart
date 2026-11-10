import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';

final _opaqueId = List.filled(43, 'a').join();
final _otherOpaqueId = List.filled(43, 'b').join();

void main() {
  group('SocialProfileCard strict codec', () {
    test('decodes only the bounded school-search card', () {
      final card = SocialProfileCard.fromWire({
        'socialProfileId': _opaqueId,
        'displayName': 'Learner',
        'avatarId': 9,
      });

      expect(card.socialProfileId, _opaqueId);
      expect(card.displayName, 'Learner');
      expect(card.avatarId, 9);
    });

    test('rejects private or unknown profile fields', () {
      expect(
        () => SocialProfileCard.fromWire({
          'socialProfileId': _opaqueId,
          'displayName': 'Learner',
          'avatarId': 0,
          'email': 'private@example.test',
        }),
        throwsFormatException,
      );
    });

    test('rejects avatar indexes outside the catalog', () {
      expect(
        () => SocialProfileCard.fromWire({
          'socialProfileId': _opaqueId,
          'displayName': 'Learner',
          'avatarId': 10,
        }),
        throwsFormatException,
      );
    });
  });

  test(
    'relationship codec rejects unsupported payload fields and state values',
    () {
      final valid = {
        'id': 'request-1',
        'fromSocialProfileId': _opaqueId,
        'toSocialProfileId': _otherOpaqueId,
        'state': 'pending',
      };
      expect(
        SocialRelationship.fromWire(valid).state,
        FollowRequestState.pending,
      );
      expect(
        () => SocialRelationship.fromWire({
          ...valid,
          'parent_session_id': 'secret',
        }),
        throwsFormatException,
      );
      expect(
        () => SocialRelationship.fromWire({...valid, 'state': 'mystery'}),
        throwsFormatException,
      );
    },
  );

  test('connections require all four bounded lists', () {
    final connections = SocialConnections.fromWire({
      'outgoingRequests': const [],
      'incomingRequests': const [],
      'following': const [],
      'followers': const [],
    });
    expect(connections.followers, isEmpty);
    expect(
      () => SocialConnections.fromWire({'followers': const []}),
      throwsFormatException,
    );
  });

  test(
    'search page codec preserves a bounded cursor and rejects unknown fields',
    () {
      final page = SocialSearchPage.fromWire({
        'profiles': [
          {
            'socialProfileId': _opaqueId,
            'displayName': 'Learner',
            'avatarId': 2,
          },
        ],
        'nextPageToken': 'membership-cursor',
      });
      expect(page.profiles.single.socialProfileId, _opaqueId);
      expect(page.nextPageToken, 'membership-cursor');
      expect(
        () => SocialSearchPage.fromWire({
          'profiles': const [],
          'nextPageToken': null,
          'ownerUid': 'not-public',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'child control codec requires unique school ids and a boolean pause state',
    () {
      final controls = SocialChildControls.fromWire({
        'allowedSchoolIds': ['school-1', 'school-2'],
        'paused': true,
      });
      expect(controls.allowedSchoolIds, ['school-1', 'school-2']);
      expect(controls.paused, isTrue);
      expect(
        () => SocialChildControls.fromWire({
          'allowedSchoolIds': ['school-1', 'school-1'],
          'paused': false,
        }),
        throwsFormatException,
      );
    },
  );
}
