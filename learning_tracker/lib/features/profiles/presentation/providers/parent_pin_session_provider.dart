import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_pin_session_provider.g.dart';

/// Profile id for which the parent PIN was verified in this app session.
///
/// When this equals the active profile id, the parent is treated as acting
/// for that (child) profile — e.g. manual lifetime completions in Settings.
// keepAlive: PIN verification must persist for the rest of the app session, not just one screen.
@Riverpod(keepAlive: true)
class ParentPinAuthenticatedProfileId
    extends _$ParentPinAuthenticatedProfileId {
  @override
  int? build() => null;

  void setAuthenticated(int profileId) => state = profileId;

  void clear() => state = null;
}
