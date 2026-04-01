/// Represents the app's authentication state, independent of Firebase.
///
/// The app always has an identity (localUid). Firebase auth is optional
/// and layers on top when the user creates a cloud account.
sealed class AppAuthState {
  const AppAuthState();

  String get displayUid;
  String get displayName;
  bool get hasCloudAccount;
  String? get firebaseUid;
}

/// Local-only auth state — no Firebase account.
///
/// The user has a stable local UUID but no cloud identity.
/// All features work fully in this state.
class LocalAuthState extends AppAuthState {
  const LocalAuthState({
    required this.localUid,
    required this.displayName,
  });

  final String localUid;

  @override
  String get displayUid => localUid;

  @override
  final String displayName;

  @override
  bool get hasCloudAccount => false;

  @override
  String? get firebaseUid => null;
}

/// Cloud auth state — user has a Firebase account.
///
/// Enables multi-device sync and cloud backup.
class CloudAuthState extends AppAuthState {
  const CloudAuthState({
    required this.localUid,
    required String firebaseUid,
    required this.displayName,
    this.email,
  }) : _firebaseUid = firebaseUid;

  final String localUid;
  final String _firebaseUid;
  final String? email;

  @override
  String get displayUid => localUid;

  @override
  final String displayName;

  @override
  bool get hasCloudAccount => true;

  @override
  String? get firebaseUid => _firebaseUid;
}
