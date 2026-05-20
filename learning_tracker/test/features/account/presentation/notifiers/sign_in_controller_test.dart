import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';

/// Throwing fake [AuthRepository] used to drive the failure path of
/// `onSendAgain` inside `SignInController.buildVerificationCallback`.
///
/// We use a hand-rolled fake (rather than mocktail) so the test stays free of
/// any extra setup and so the regression target — the empty-catch fix in
/// `sign_in_controller.dart` — is exercised end-to-end through the real
/// production controller closure.
class _ThrowingAuthRepository implements AuthRepository {
  int sendCount = 0;

  @override
  Future<void> sendEmailVerification() async {
    sendCount++;
    throw Exception('simulated send-verification failure');
  }

  // ── Members not exercised by this test. ────────────────────────────────────
  @override
  AppUser? get currentUser => null;

  @override
  Future<void> applyActionCode(String oobCode) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword(String newPassword) =>
      throw UnimplementedError();

  @override
  Future<void> checkActionCode(String oobCode) =>
      throw UnimplementedError();

  @override
  Future<String> createUserAccount(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();

  @override
  Future<void> deleteCurrentFirebaseUser() => throw UnimplementedError();

  @override
  List<String> getLinkedProviders() => const <String>[];

  @override
  bool isSignInWithEmailLink(String link) => false;

  @override
  Future<void> linkEmailProvider(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> linkGoogleProvider() => throw UnimplementedError();

  @override
  Stream<AppUser?> onAuthStateChanged() => const Stream<AppUser?>.empty();

  @override
  Future<AppUser?> reauthenticateWithGoogle() =>
      throw UnimplementedError();

  @override
  Future<void> reauthenticateWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> reloadCurrentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> sendSignInLinkToEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> signInAndGetUser(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AppUser?> signInWithEmailLink(String email, String emailLink) =>
      throw UnimplementedError();

  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp(String email, String password, String displayName) =>
      throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String displayName) =>
      throw UnimplementedError();
}

void main() {
  group('SignInController.resendVerificationEmail', () {
    setUp(() {
      // Reset the AppLogger singleton so each test starts with an empty Talker
      // history. AppLogger.init() returns a fresh Talker and clears the cached
      // AppLogger.instance.
      AppLogger.init();
    });

    test(
      'logs a warning via AppLogger when sendEmailVerification throws '
      '(replaces the previously swallowed empty catch)',
      () async {
        final throwingAuth = _ThrowingAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(throwingAuth),
          ],
        );
        addTearDown(container.dispose);

        // Realize the controller — this binds its internal `_ref` to the
        // overridden container, so subsequent reads of authRepositoryProvider
        // return the throwing fake.
        final controller = container.read(signInControllerProvider.notifier);

        // Drive the extracted catch-bearing method directly. No dialog UI is
        // involved — we exercise the exact production line that replaced the
        // former empty catch.
        await controller.resendVerificationEmail();

        // The real production code reached the throwing fake exactly once.
        expect(throwingAuth.sendCount, 1);

        // AppLogger.warning produced an entry mentioning the event name. We
        // assert against the rendered message string because that is what
        // flows to operators inspecting logs.
        final history = AppLogger.instance.talker.history;
        final messages = history
            .map((entry) => entry.generateTextMessage())
            .toList();

        expect(
          messages.any(
            (m) => m.contains('send_verification_email_failed'),
          ),
          isTrue,
          reason:
              'Expected AppLogger.warning(event: "send_verification_email_failed") '
              'to be emitted. Talker history: $messages',
        );
        expect(
          messages.any((m) => m.contains('simulated send-verification failure')),
          isTrue,
          reason:
              'Expected the underlying exception to be attached to the log entry. '
              'Talker history: $messages',
        );
      },
    );
  });
}
