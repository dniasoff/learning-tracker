import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/auth/domain/models/app_auth_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state_provider.g.dart';

/// Single source of truth for the app's authentication state.
///
/// NOTE: This is a transitional stub for Epic 20 story 20.3 (schema
/// migration). Story 20.5 will replace the sealed [AppAuthState]
/// hierarchy with a unified [AuthState] notifier carrying
/// `currentUser + tier + sessionStatus`. Until then, this stub keeps
/// existing callers compiling against the new schema.
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AppAuthState build() {
    _initAsync();
    return const LocalAuthState(localUid: '', displayName: '');
  }

  Future<void> _initAsync() async {
    final db = ref.read(userDatabaseProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      final profile =
          await db.userProfileDao.getUserProfileByFirebaseUid(firebaseUser.uid);
      if (profile != null) {
        state = CloudAuthState(
          localUid: firebaseUser.uid,
          firebaseUid: firebaseUser.uid,
          displayName: profile.displayName,
          email: firebaseUser.email,
        );
        return;
      }
    }

    // Fall back to local state — 20.5 will surface real local-born accounts.
    final profiles = await db.userProfileDao.getAllUserProfiles();
    if (profiles.isNotEmpty) {
      final profile = profiles.first;
      state = LocalAuthState(
        localUid: profile.email,
        displayName: profile.displayName,
      );
    }
  }

  /// Called when user creates/links a Firebase account.
  /// TODO(20.5/20.9): replace with real upgrade flow.
  Future<void> promoteToCloud(User firebaseUser) async {
    final currentState = state;
    state = CloudAuthState(
      localUid: firebaseUser.uid,
      firebaseUid: firebaseUser.uid,
      displayName: currentState.displayName,
      email: firebaseUser.email,
    );
  }

  /// Called on sign-out.
  /// TODO(20.5): replace with real session clear.
  void demoteToLocal() {
    state = LocalAuthState(
      localUid: state.displayUid,
      displayName: state.displayName,
    );
  }
}
