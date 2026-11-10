/// A profile card returned only by a bounded, server-mediated school search.
final class SocialProfileCard {
  const SocialProfileCard({
    required this.socialProfileId,
    required this.displayName,
    required this.avatarId,
  });

  final String socialProfileId;
  final String displayName;
  final int avatarId;

  factory SocialProfileCard.fromWire(Object? value) {
    final data = _strictMap(value, const {
      'socialProfileId',
      'displayName',
      'avatarId',
    });
    final avatar = data['avatarId'];
    if (avatar is! int || avatar < 0 || avatar > 9) {
      throw const FormatException(
        'avatarId must be one of the catalog indexes',
      );
    }
    return SocialProfileCard(
      socialProfileId: _opaqueSocialId(
        data['socialProfileId'],
        'socialProfileId',
      ),
      displayName: _requiredString(data['displayName'], 'displayName'),
      avatarId: avatar,
    );
  }
}

enum FollowRequestState { pending, accepted, declined, expired, active }

final class SocialChildControls {
  const SocialChildControls({
    required this.allowedSchoolIds,
    required this.paused,
  });

  final List<String> allowedSchoolIds;
  final bool paused;

  factory SocialChildControls.fromWire(Object? value) {
    final data = _strictMap(value, const {'allowedSchoolIds', 'paused'});
    final schools = data['allowedSchoolIds'];
    if (schools is! List ||
        schools.any((school) => school is! String) ||
        data['paused'] is! bool ||
        schools.toSet().length != schools.length) {
      throw const FormatException('Invalid child social controls');
    }
    return SocialChildControls(
      allowedSchoolIds: List.unmodifiable(schools.cast<String>()),
      paused: data['paused'] as bool,
    );
  }
}

/// Minimal social edge/request data. It intentionally carries no progress,
/// account email, or other private profile fields.
final class SocialRelationship {
  const SocialRelationship({
    required this.id,
    required this.fromSocialProfileId,
    required this.toSocialProfileId,
    required this.state,
  });

  final String id;
  final String fromSocialProfileId;
  final String toSocialProfileId;
  final FollowRequestState state;

  factory SocialRelationship.fromWire(Object? value) {
    final data = _strictMap(
      value,
      const {
        'id',
        'fromSocialProfileId',
        'toSocialProfileId',
        'state',
        'created_at',
        'updated_at',
        'expires_at',
      },
      requiredKeys: const {
        'id',
        'fromSocialProfileId',
        'toSocialProfileId',
        'state',
      },
    );
    final state = switch (data['state']) {
      'pending' => FollowRequestState.pending,
      'accepted' => FollowRequestState.accepted,
      'declined' => FollowRequestState.declined,
      'expired' => FollowRequestState.expired,
      'active' => FollowRequestState.active,
      _ => throw const FormatException('Unknown social relationship state'),
    };
    for (final key in const ['created_at', 'updated_at', 'expires_at']) {
      if (data.containsKey(key) && !_isWireTimestamp(data[key])) {
        throw FormatException('$key must be a server timestamp');
      }
    }
    return SocialRelationship(
      id: _requiredString(data['id'], 'id'),
      fromSocialProfileId: _opaqueSocialId(
        data['fromSocialProfileId'],
        'fromSocialProfileId',
      ),
      toSocialProfileId: _opaqueSocialId(
        data['toSocialProfileId'],
        'toSocialProfileId',
      ),
      state: state,
    );
  }
}

final class SocialConnections {
  const SocialConnections({
    required this.outgoingRequests,
    required this.incomingRequests,
    required this.following,
    required this.followers,
  });

  final List<SocialRelationship> outgoingRequests;
  final List<SocialRelationship> incomingRequests;
  final List<SocialRelationship> following;
  final List<SocialRelationship> followers;

  factory SocialConnections.fromWire(Object? value) {
    final data = _strictMap(value, const {
      'outgoingRequests',
      'incomingRequests',
      'following',
      'followers',
    });
    List<SocialRelationship> decodeList(Object? value, String key) {
      if (value is! List) throw FormatException('$key must be a list');
      return List.unmodifiable(value.map(SocialRelationship.fromWire));
    }

    return SocialConnections(
      outgoingRequests: decodeList(
        data['outgoingRequests'],
        'outgoingRequests',
      ),
      incomingRequests: decodeList(
        data['incomingRequests'],
        'incomingRequests',
      ),
      following: decodeList(data['following'], 'following'),
      followers: decodeList(data['followers'], 'followers'),
    );
  }
}

final class SocialSearchPage {
  const SocialSearchPage({required this.profiles, this.nextPageToken});

  final List<SocialProfileCard> profiles;
  final String? nextPageToken;

  factory SocialSearchPage.fromWire(Object? value) {
    final data = _strictMap(value, const {'profiles', 'nextPageToken'});
    final profiles = data['profiles'];
    final token = data['nextPageToken'];
    if (profiles is! List ||
        token != null && (token is! String || token.isEmpty)) {
      throw const FormatException('Invalid social search page');
    }
    return SocialSearchPage(
      profiles: List.unmodifiable(profiles.map(SocialProfileCard.fromWire)),
      nextPageToken: token as String?,
    );
  }
}

Map<String, Object?> _strictMap(
  Object? value,
  Set<String> allowedKeys, {
  Set<String>? requiredKeys,
}) {
  if (value is! Map) throw const FormatException('Expected an object');
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String || !allowedKeys.contains(entry.key)) {
      throw FormatException('Unsupported field: ${entry.key}');
    }
    map[entry.key as String] = entry.value;
  }
  if ((requiredKeys ?? allowedKeys).any((key) => !map.containsKey(key))) {
    throw const FormatException('Required field is missing');
  }
  return map;
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty || value.length > 128) {
    throw FormatException('$name must be a non-empty string');
  }
  return value;
}

String _opaqueSocialId(Object? value, String name) {
  if (value == 'unavailable') return 'unavailable';
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value)) {
    throw FormatException('$name must be an opaque social profile id');
  }
  return value;
}

bool _isWireTimestamp(Object? value) =>
    value is DateTime ||
    value is String && DateTime.tryParse(value) != null ||
    value is Map &&
        value.length == 2 &&
        value['_seconds'] is int &&
        value['_nanoseconds'] is int;
