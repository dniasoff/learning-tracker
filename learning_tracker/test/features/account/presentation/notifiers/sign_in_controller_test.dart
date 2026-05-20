import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/notifiers/sign_in_controller.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

/// Sentinel exception that the catch path must observe and log. We use a
/// custom type so the assertion can be precise: "the catch saw OUR exception"
/// is stronger than "the catch saw SOME exception".
class _StubDatabaseFailure implements Exception {
  const _StubDatabaseFailure(this.message);
  final String message;

  @override
  String toString() => '_StubDatabaseFailure: $message';
}

/// Returns the rendered log messages for any entry that mentions [event].
Iterable<String> _entriesMentioning(String event) {
  return AppLogger.instance.talker.history
      .map((entry) => entry.generateTextMessage())
      .where((m) => m.contains(event));
}

/// Builds a DeviceAccount fixture for the offline-cloud-restore catch test.
/// Tier is `cloudBorn` so the catch triggers via the cloud-restore branch
/// rather than getting routed to the local fallback.
DeviceAccount _cloudAccount() => DeviceAccount(
      accountId: 'acc-cloud-1',
      email: 'cloud@example.com',
      displayName: 'Cloud User',
      tier: 'cloudBorn',
      firebaseUid: 'fb-uid-1',
      avatarIndex: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      lastUsedAt: DateTime.utc(2026, 1, 1),
      dbFileName: 'user_acc_cloud_1.db',
    );

void main() {
  setUp(() {
    // Reset the AppLogger singleton so each test starts with an empty Talker
    // history. AppLogger.init() returns a fresh Talker and clears the cached
    // AppLogger.instance.
    AppLogger.init();
  });

  group('SignInController.resendVerificationEmail', () {
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

  // ── F19: empty-catch logging in offline / local-fallback paths ─────────────
  //
  // Both `_tryLocalFallbackSignIn` and `_tryOfflineCloudRestore` used to
  // swallow EVERY exception with an empty `catch (_)`. A broken DB, a prefs
  // corruption, a navigation crash — all manifested as an "incorrect
  // password" toast with zero operator trace. The fix replaces each empty
  // catch with `AppLogger.warning(event: …, exception: e, stackTrace: st)`.
  //
  // Both helpers are now exposed via `@visibleForTesting` shims so the
  // catch path runs the EXACT production lines (no copy of the logic in
  // the test). We override `userDatabaseProvider` to throw a sentinel
  // exception — that throw propagates through `_ref.read(...)` inside the
  // `try` block and lands in the `catch`, exercising the AppLogger call.

  group('SignInController.tryLocalFallbackSignInForTest — F19 logging', () {
    test(
      'logs a warning via AppLogger when an unexpected exception is thrown '
      '(replaces the previously swallowed empty catch)',
      () async {
        // Force `userDatabaseProvider` to throw on first read. This throw
        // propagates out of `final dao = _ref.read(userDatabaseProvider)
        // .userProfileDao` inside `_tryLocalFallbackSignIn` and lands in the
        // catch — which is the line the F19 fix added the AppLogger.warning
        // call to.
        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith(
              (ref) => throw const _StubDatabaseFailure('user db unavailable'),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(signInControllerProvider.notifier);

        // Drive the production code through the visible-for-tests shim. The
        // method must return false (catch path) and the AppLogger must
        // observe the exception.
        final result = await controller.tryLocalFallbackSignInForTest(
          email: 'test@example.com',
          password: 'whatever',
          router: _StubRouter(),
          // The catch path doesn't reference l10n, so any non-null instance
          // would do — but the helper signature demands it.
          l10n: await _stubL10n(),
        );

        expect(
          result,
          isFalse,
          reason:
              'helper must return false when an unexpected exception is '
              'caught (matches the legacy contract — the only change is the '
              'log emission).',
        );

        final entries = _entriesMentioning('try_local_fallback_sign_in_failed')
            .toList();
        expect(
          entries,
          isNotEmpty,
          reason:
              'Expected AppLogger.warning(event: "try_local_fallback_sign_in_failed") '
              'to be emitted. Talker history: '
              '${AppLogger.instance.talker.history.map((e) => e.generateTextMessage()).toList()}',
        );
        expect(
          entries.any((m) => m.contains('user db unavailable')),
          isTrue,
          reason:
              'Expected the underlying exception message to be attached. '
              'Captured entries: $entries',
        );
      },
    );
  });

  group('SignInController.tryOfflineCloudRestoreForTest — F19 logging', () {
    test(
      'logs a warning via AppLogger when an unexpected exception is thrown '
      '(replaces the previously swallowed empty catch)',
      () async {
        // Same trick — `userDatabaseProvider` throws so the read inside
        // `_tryOfflineCloudRestore` (right after the file-name swap)
        // immediately propagates into the catch block.
        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith(
              (ref) => throw const _StubDatabaseFailure(
                'offline db swap failed',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(signInControllerProvider.notifier);

        final result = await controller.tryOfflineCloudRestoreForTest(
          _cloudAccount(),
          _StubRouter(),
        );

        expect(
          result,
          isFalse,
          reason:
              'helper must return false when an unexpected exception is '
              'caught.',
        );

        final entries = _entriesMentioning('try_offline_cloud_restore_failed')
            .toList();
        expect(
          entries,
          isNotEmpty,
          reason:
              'Expected AppLogger.warning(event: "try_offline_cloud_restore_failed") '
              'to be emitted. Talker history: '
              '${AppLogger.instance.talker.history.map((e) => e.generateTextMessage()).toList()}',
        );
        expect(
          entries.any((m) => m.contains('offline db swap failed')),
          isTrue,
          reason:
              'Expected the underlying exception message to be attached. '
              'Captured entries: $entries',
        );
      },
    );
  });
}

/// Minimal StackRouter stub — the catch path returns BEFORE any navigation
/// is attempted, so we never actually call any of its methods.
class _StubRouter implements StackRouter {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(
        'StubRouter received an unexpected call: ${invocation.memberName}',
      );
}

/// Lazily realise the AppLocalizations instance the controller expects. The
/// catch path never references l10n so this can be any non-null instance.
Future<AppLocalizations> _stubL10n() async {
  // The `enUs` locale is supported and matches the default ARB.
  return AppLocalizations.delegate.load(const Locale('en'));
}
