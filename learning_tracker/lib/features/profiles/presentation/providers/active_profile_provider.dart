import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_profile_provider.g.dart';

/// Holds the active profile ID for the current session.
///
/// All profile-scoped providers watch this value and rebuild when it changes.
/// Default value 0 represents the legacy/default profile.
@riverpod
class ActiveProfileId extends _$ActiveProfileId {
  @override
  int build() => 0;

  /// Switch to a different profile.
  void switchTo(int profileId) {
    state = profileId;
  }
}
