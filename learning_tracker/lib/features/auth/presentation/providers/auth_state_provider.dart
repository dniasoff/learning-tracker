import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/auth/domain/models/app_auth_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

part 'auth_state_provider.g.dart';

const _kLocalDeviceUid = 'local_device_uid';

/// Single source of truth for the app's authentication state.
///
/// Resolves synchronously from local DB — zero network calls.
/// On startup, always emits [LocalAuthState] first (instant).
/// If the user has a cloud account and Firebase is ready,
/// promotes to [CloudAuthState].
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AppAuthState build() {
    // Start with local state — resolves synchronously
    _initAsync();
    return LocalAuthState(
      localUid: _getOrCreateLocalUid(),
      displayName: '',
    );
  }

  String _getOrCreateLocalUid() {
    final prefs = SharedPreferencesAsync();
    // SharedPreferencesAsync doesn't have sync read, so we use a
    // cached value or generate one. The async init will set the
    // definitive value.
    return const Uuid().v4(); // Placeholder until async init
  }

  Future<void> _initAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final localUid = prefs.getString(_kLocalDeviceUid) ?? const Uuid().v4();
    if (!prefs.containsKey(_kLocalDeviceUid)) {
      await prefs.setString(_kLocalDeviceUid, localUid);
    }

    // Check if user has a cloud account
    final db = ref.read(userDatabaseProvider);
    final userProfile = await (db.select(db.userProfiles)
          ..where((t) => t.localUid.equals(localUid)))
        .getSingleOrNull();

    if (userProfile != null && userProfile.hasAccount) {
      // Try to read Firebase current user (synchronous property, no network)
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        state = CloudAuthState(
          localUid: localUid,
          firebaseUid: firebaseUser.uid,
          displayName: userProfile.displayName,
          email: firebaseUser.email,
        );
        return;
      }
    }

    // Default: local auth state
    state = LocalAuthState(
      localUid: localUid,
      displayName: userProfile?.displayName ?? '',
    );
  }

  /// Called when user creates/links a Firebase account.
  Future<void> promoteToCloud(User firebaseUser) async {
    final currentState = state;
    final localUid = currentState.displayUid;

    // Update UserProfiles table
    final db = ref.read(userDatabaseProvider);
    await (db.update(db.userProfiles)
          ..where((t) => t.localUid.equals(localUid)))
        .write(UserProfilesCompanion(
      firebaseUid: Value(firebaseUser.uid),
      hasAccount: const Value(true),
      updatedAt: Value(DateTime.now().toUtc()),
    ));

    state = CloudAuthState(
      localUid: localUid,
      firebaseUid: firebaseUser.uid,
      displayName: currentState.displayName,
      email: firebaseUser.email,
    );
  }

  /// Called on sign-out.
  void demoteToLocal() {
    final currentState = state;
    final localUid = currentState.displayUid;

    // Update UserProfiles table
    final db = ref.read(userDatabaseProvider);
    (db.update(db.userProfiles)
          ..where((t) => t.localUid.equals(localUid)))
        .write(UserProfilesCompanion(
      firebaseUid: const Value(null),
      hasAccount: const Value(false),
      updatedAt: Value(DateTime.now().toUtc()),
    ));

    state = LocalAuthState(
      localUid: localUid,
      displayName: currentState.displayName,
    );
  }
}
