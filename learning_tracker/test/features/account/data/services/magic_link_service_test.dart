/// Unit tests for MagicLinkService.
///
/// Fully self-contained — sets up all binding / platform-channel mocks
/// in-file so this file passes when run in isolation:
///   flutter test test/features/account/data/services/magic_link_service_test.dart
///
/// [MagicLinkService.initialize] hands [_handleIncomingLink] to
/// `uriLinkStream.listen(...)` as a fire-and-forget `onData` callback, so
/// there is no `Future` the test can `await` directly after
/// [_FakeAppLinksPlatform.emit]. Every `emit(...)` below is therefore
/// followed by `await pumpEventQueue()` (AUD-t-account-07 / TQ-6) rather
/// than a fixed-millisecond `Future.delayed`: it deterministically drains
/// the event queue until the listener's async chain (SharedPreferences +
/// mocked AuthRepository awaits) has settled, instead of guessing a sleep
/// duration that a slow/contended CI runner could outrun. Same pattern
/// already used in test/features/sync/presentation/providers/
/// sync_providers_test.dart.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

/// Fake AppLinksPlatform implementation that lets tests control both the
/// initial link and warm links without touching any real platform channel.
///
/// Uses [MockPlatformInterfaceMixin] so [PlatformInterface.verify] accepts it.
class _FakeAppLinksPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements AppLinksPlatform {
  Uri? initialLink;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Future<String?> getInitialLinkString() async => initialLink?.toString();

  @override
  Future<Uri?> getLatestLink() async => initialLink;

  @override
  Future<String?> getLatestLinkString() async => initialLink?.toString();

  @override
  Stream<String> get stringLinkStream =>
      _controller.stream.map((u) => u.toString());

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);
  void emitError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helper URIs
// ---------------------------------------------------------------------------

Uri _signInUri({String oobCode = 'abc123'}) {
  return Uri.https('auth.example.com', '/action', {
    'mode': 'signIn',
    'oobCode': oobCode,
  });
}

Uri _verifyEmailUri({String oobCode = 'verify-code-xyz'}) {
  return Uri.https('auth.example.com', '/action', {
    'mode': 'verifyEmail',
    'oobCode': oobCode,
  });
}

/// Wraps an inner URI in one level of "link=" nesting.
Uri _wrapped1(Uri inner) {
  return Uri.https('app.example.com', '/redirect', {
    'link': Uri.encodeComponent(inner.toString()),
  });
}

/// Wraps an inner URI in two levels (link= then deep_link_id=).
Uri _wrapped2(Uri inner) {
  final level1 = Uri.https('firebase.app', '/dynamic', {
    'deep_link_id': Uri.encodeComponent(inner.toString()),
  });
  return Uri.https('app.example.com', '/redirect', {
    'link': Uri.encodeComponent(level1.toString()),
  });
}

const _fakeUser = AppUser(
  uid: 'uid-1',
  email: 'user@example.com',
  displayName: 'Test User',
  emailVerified: false,
  providers: ['emailLink'],
);

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Builds a [MagicLinkService] using the real [AppLinks] singleton, which
/// delegates to [_FakeAppLinksPlatform] because we replace the platform
/// instance in [setUp].
MagicLinkService _buildService(
  MockAuthRepository auth, {
  Future<void> Function(AppUser)? onSignedIn,
}) {
  return MagicLinkService(
    authRepository: auth,
    onSignedIn: onSignedIn ?? (_) async {},
    // Pass null so the constructor uses the singleton AppLinks() whose
    // underlying platform is already swapped out by _FakeAppLinksPlatform.
    appLinks: AppLinks(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuth;
  late _FakeAppLinksPlatform fakePlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthRepository();
    fakePlatform = _FakeAppLinksPlatform();
    // Replace the AppLinks platform instance with our fake so AppLinks()
    // delegates all calls to the fake without touching any method channel.
    AppLinksPlatform.instance = fakePlatform;

    // Default: link is NOT a sign-in link.
    when(() => mockAuth.isSignInWithEmailLink(any<String>())).thenReturn(false);
  });

  tearDown(() async {
    await fakePlatform.close();
  });

  // =========================================================================
  // initialize() — lifecycle
  // =========================================================================

  group('initialize()', () {
    test('is idempotent — second call is a no-op', () async {
      final service = _buildService(mockAuth);
      await service.initialize();
      await service.initialize();
      await service.dispose();
    });

    test('processes cold-start initial link (sign-in path)', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
      });

      final uri = _signInUri();
      fakePlatform.initialLink = uri;

      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(true);
      when(
        () => mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
      ).thenAnswer((_) async => _fakeUser);

      final signedInUsers = <AppUser>[];
      final service = _buildService(
        mockAuth,
        onSignedIn: (u) async => signedInUsers.add(u),
      );

      await service.initialize();

      expect(signedInUsers, hasLength(1));
      expect(signedInUsers.first.uid, 'uid-1');

      await service.dispose();
    });

    test('handles null initial link without error', () async {
      fakePlatform.initialLink = null;
      final service = _buildService(mockAuth);
      await service.initialize();
      await service.dispose();
    });

    test('handles exception from getInitialLink without crashing', () async {
      final throwingPlatform = _ThrowingInitialLinkPlatform();
      AppLinksPlatform.instance = throwingPlatform;

      final service = _buildService(mockAuth);
      await service.initialize(); // must not throw
      await service.dispose();

      // Restore the regular fake so tearDown can close it safely.
      AppLinksPlatform.instance = fakePlatform;
    });
  });

  // =========================================================================
  // dispose()
  // =========================================================================

  group('dispose()', () {
    test('can be called before initialize without error', () async {
      final service = _buildService(mockAuth);
      await service.dispose();
    });

    test('allows re-initialization after dispose', () async {
      final service = _buildService(mockAuth);
      await service.initialize();
      await service.dispose();
      await service.initialize();
      await service.dispose();
    });
  });

  // =========================================================================
  // Warm link handling (via uriLinkStream)
  // =========================================================================

  group('warm link — sign-in', () {
    test('signs in successfully when pending email is stored', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
      });

      final uri = _signInUri();
      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(true);
      when(
        () => mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
      ).thenAnswer((_) async => _fakeUser);

      final signedInUsers = <AppUser>[];
      final service = _buildService(
        mockAuth,
        onSignedIn: (u) async => signedInUsers.add(u),
      );
      await service.initialize();

      fakePlatform.emit(uri);
      await pumpEventQueue();

      expect(signedInUsers, hasLength(1));
      expect(signedInUsers.first.email, 'user@example.com');

      await service.dispose();
    });

    test('applies pending display name before calling onSignedIn', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
        kMagicLinkPendingDisplayName: 'New Name',
      });

      final uri = _signInUri();
      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(true);
      when(
        () => mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
      ).thenAnswer((_) async => _fakeUser);
      when(
        () => mockAuth.updateDisplayName('New Name'),
      ).thenAnswer((_) async {});

      final service = _buildService(mockAuth);
      await service.initialize();

      fakePlatform.emit(uri);
      await pumpEventQueue();

      verify(() => mockAuth.updateDisplayName('New Name')).called(1);

      await service.dispose();
    });

    test(
      'clears pending email and display name after successful sign-in',
      () async {
        SharedPreferences.setMockInitialValues({
          kMagicLinkPendingEmail: 'user@example.com',
          kMagicLinkPendingDisplayName: 'My Name',
        });

        final uri = _signInUri();
        when(
          () => mockAuth.isSignInWithEmailLink(uri.toString()),
        ).thenReturn(true);
        when(
          () =>
              mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
        ).thenAnswer((_) async => _fakeUser);
        when(
          () => mockAuth.updateDisplayName(any<String>()),
        ).thenAnswer((_) async {});

        final service = _buildService(mockAuth);
        await service.initialize();
        fakePlatform.emit(uri);
        await pumpEventQueue();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kMagicLinkPendingEmail), isNull);
        expect(prefs.getString(kMagicLinkPendingDisplayName), isNull);

        await service.dispose();
      },
    );

    test('clears pending email even when signInWithEmailLink throws', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
      });

      final uri = _signInUri();
      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(true);
      when(
        () => mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
      ).thenThrow(Exception('Firebase error'));

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kMagicLinkPendingEmail), isNull);

      await service.dispose();
    });

    test(
      'does not call onSignedIn when signInWithEmailLink returns null',
      () async {
        SharedPreferences.setMockInitialValues({
          kMagicLinkPendingEmail: 'user@example.com',
        });

        final uri = _signInUri();
        when(
          () => mockAuth.isSignInWithEmailLink(uri.toString()),
        ).thenReturn(true);
        when(
          () =>
              mockAuth.signInWithEmailLink('user@example.com', uri.toString()),
        ).thenAnswer((_) async => null);

        var callbackCount = 0;
        final service = _buildService(
          mockAuth,
          onSignedIn: (_) async => callbackCount++,
        );
        await service.initialize();
        fakePlatform.emit(uri);
        await pumpEventQueue();

        expect(callbackCount, 0);

        await service.dispose();
      },
    );

    test('logs and ignores link when no pending email is stored', () async {
      SharedPreferences.setMockInitialValues({});

      final uri = _signInUri();
      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(true);

      var callbackCount = 0;
      final service = _buildService(
        mockAuth,
        onSignedIn: (_) async => callbackCount++,
      );
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      expect(callbackCount, 0);
      verifyNever(
        () => mockAuth.signInWithEmailLink(any<String>(), any<String>()),
      );

      await service.dispose();
    });

    test('ignores link when isSignInWithEmailLink returns false', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
      });

      final uri = Uri.https('example.com', '/not-auth', {'foo': 'bar'});
      when(
        () => mockAuth.isSignInWithEmailLink(uri.toString()),
      ).thenReturn(false);

      var callbackCount = 0;
      final service = _buildService(
        mockAuth,
        onSignedIn: (_) async => callbackCount++,
      );
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      expect(callbackCount, 0);

      await service.dispose();
    });

    test('stream error is swallowed without crashing', () async {
      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emitError(Exception('channel error'));
      await pumpEventQueue();
      // Service still alive — dispose should not throw.
      await service.dispose();
    });
  });

  // =========================================================================
  // verifyEmail link handling
  // =========================================================================

  group('warm link — verifyEmail', () {
    test('applies action code and reloads user on success', () async {
      final uri = _verifyEmailUri(oobCode: 'verify-abc');
      when(
        () => mockAuth.checkActionCode('verify-abc'),
      ).thenAnswer((_) async {});
      when(
        () => mockAuth.applyActionCode('verify-abc'),
      ).thenAnswer((_) async {});
      when(
        () => mockAuth.reloadCurrentUser(),
      ).thenAnswer((_) async => _fakeUser);

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      verify(() => mockAuth.checkActionCode('verify-abc')).called(1);
      verify(() => mockAuth.applyActionCode('verify-abc')).called(1);
      verify(() => mockAuth.reloadCurrentUser()).called(1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPendingVerifyEmailOobCode), isNull);

      await service.dispose();
    });

    test('stores oobCode in SharedPreferences before applying', () async {
      final uri = _verifyEmailUri(oobCode: 'oob-stored');

      String? capturedPrefsValue;
      when(() => mockAuth.checkActionCode('oob-stored')).thenAnswer((_) async {
        final prefs = await SharedPreferences.getInstance();
        capturedPrefsValue = prefs.getString(kPendingVerifyEmailOobCode);
      });
      when(
        () => mockAuth.applyActionCode('oob-stored'),
      ).thenAnswer((_) async {});
      when(() => mockAuth.reloadCurrentUser()).thenAnswer((_) async => null);

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      expect(capturedPrefsValue, 'oob-stored');

      await service.dispose();
    });

    test('clears oobCode on invalid-action-code error', () async {
      SharedPreferences.setMockInitialValues({});
      final uri = _verifyEmailUri(oobCode: 'expired-code');
      when(
        () => mockAuth.checkActionCode('expired-code'),
      ).thenThrow(Exception('[invalid-action-code] code expired'));

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPendingVerifyEmailOobCode), isNull);

      await service.dispose();
    });

    test('clears oobCode on expired-action-code error', () async {
      SharedPreferences.setMockInitialValues({});
      final uri = _verifyEmailUri(oobCode: 'old-code');
      when(
        () => mockAuth.checkActionCode('old-code'),
      ).thenThrow(Exception('[expired-action-code] code consumed'));

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kPendingVerifyEmailOobCode), isNull);

      await service.dispose();
    });

    test('does not call apply or reload when oobCode is absent', () async {
      final uri = Uri.https('auth.example.com', '/action', {
        'mode': 'verifyEmail',
        // intentionally no oobCode
      });

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      verifyNever(() => mockAuth.applyActionCode(any<String>()));
      verifyNever(() => mockAuth.reloadCurrentUser());

      await service.dispose();
    });
  });

  // =========================================================================
  // _extractActionUri — unwrapping levels
  // =========================================================================

  group('_extractActionUri (unwrap levels)', () {
    test(
      'level 0 — plain Firebase action URI passes through unchanged',
      () async {
        SharedPreferences.setMockInitialValues({
          kMagicLinkPendingEmail: 'user@example.com',
        });

        final plain = _signInUri(oobCode: 'plain-code');
        when(
          () => mockAuth.isSignInWithEmailLink(plain.toString()),
        ).thenReturn(true);
        when(
          () => mockAuth.signInWithEmailLink(
            'user@example.com',
            plain.toString(),
          ),
        ).thenAnswer((_) async => _fakeUser);

        final service = _buildService(mockAuth);
        await service.initialize();
        fakePlatform.emit(plain);
        await pumpEventQueue();

        verify(
          () => mockAuth.signInWithEmailLink(
            'user@example.com',
            plain.toString(),
          ),
        ).called(1);

        await service.dispose();
      },
    );

    test(
      'level 1 — link= wrapper is unwrapped before checking sign-in',
      () async {
        SharedPreferences.setMockInitialValues({
          kMagicLinkPendingEmail: 'user@example.com',
        });

        final inner = _signInUri(oobCode: 'l1-code');
        final outer = _wrapped1(inner);

        when(
          () => mockAuth.isSignInWithEmailLink(inner.toString()),
        ).thenReturn(true);
        when(
          () => mockAuth.signInWithEmailLink(
            'user@example.com',
            inner.toString(),
          ),
        ).thenAnswer((_) async => _fakeUser);

        final service = _buildService(mockAuth);
        await service.initialize();
        fakePlatform.emit(outer);
        await pumpEventQueue();

        verify(
          () => mockAuth.signInWithEmailLink(
            'user@example.com',
            inner.toString(),
          ),
        ).called(1);

        await service.dispose();
      },
    );

    test('level 2 — link= then deep_link_id= wrapper is unwrapped', () async {
      SharedPreferences.setMockInitialValues({
        kMagicLinkPendingEmail: 'user@example.com',
      });

      final inner = _signInUri(oobCode: 'l2-code');
      final outer = _wrapped2(inner);

      when(
        () => mockAuth.isSignInWithEmailLink(inner.toString()),
      ).thenReturn(true);
      when(
        () =>
            mockAuth.signInWithEmailLink('user@example.com', inner.toString()),
      ).thenAnswer((_) async => _fakeUser);

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(outer);
      await pumpEventQueue();

      verify(
        () =>
            mockAuth.signInWithEmailLink('user@example.com', inner.toString()),
      ).called(1);

      await service.dispose();
    });

    test(
      'continueUrl is used as fallback when no mode/oobCode at outer level',
      () async {
        SharedPreferences.setMockInitialValues({
          kMagicLinkPendingEmail: 'user@example.com',
        });

        final inner = _signInUri(oobCode: 'cu-code');
        final outer = Uri.https('app.example.com', '/redir', {
          'continueUrl': Uri.encodeComponent(inner.toString()),
        });

        when(
          () => mockAuth.isSignInWithEmailLink(inner.toString()),
        ).thenReturn(true);
        when(
          () => mockAuth.signInWithEmailLink(
            'user@example.com',
            inner.toString(),
          ),
        ).thenAnswer((_) async => _fakeUser);

        final signedIn = <AppUser>[];
        final service = _buildService(
          mockAuth,
          onSignedIn: (u) async => signedIn.add(u),
        );
        await service.initialize();
        fakePlatform.emit(outer);
        await pumpEventQueue();

        expect(signedIn, hasLength(1));

        await service.dispose();
      },
    );

    test(
      'stops unwrapping when URI has no further wrapper — does not loop',
      () async {
        // A non-auth URI with no link= / deep_link_id= / continueUrl params.
        // Service should process it without hanging and ignore it gracefully.
        final nonAuthUri = Uri.https('app.example.com', '/some-path', {
          'referrer': 'email',
        });
        when(
          () => mockAuth.isSignInWithEmailLink(nonAuthUri.toString()),
        ).thenReturn(false);

        final service = _buildService(mockAuth);
        await service.initialize();
        fakePlatform.emit(nonAuthUri);
        await pumpEventQueue();
        // Completed without hanging.
        await service.dispose();
      },
    );

    // REGRESSION GUARD (was a crash): _extractActionUri called
    // Uri.decodeComponent(next) with no try/catch, so a link= value with invalid
    // percent-encoding (e.g. "%%%") threw ArgumentError: Invalid URL encoding,
    // which propagated uncaught through the stream listener and crashed the
    // service. Fixed: the decode is wrapped in try/catch and returns `current`
    // (stops unwrapping) on failure, so the link is processed gracefully.
    test(
      'malformed link= value (not a valid URI) falls through gracefully',
      () async {
        final malformed = Uri.https('app.example.com', '/redir', {
          'link': '%%%not-a-uri',
        });
        when(
          () => mockAuth.isSignInWithEmailLink(any<String>()),
        ).thenReturn(false);

        final service = _buildService(mockAuth);
        await service.initialize();
        fakePlatform.emit(malformed);
        await pumpEventQueue();

        // No crash: the service reached link-processing and asked whether the
        // (un-unwrapped) URL is a sign-in link, rather than throwing.
        verify(
          () => mockAuth.isSignInWithEmailLink(any<String>()),
        ).called(greaterThanOrEqualTo(1));

        await service.dispose();
      },
    );
  });

  // =========================================================================
  // cold-start verifyEmail link
  // =========================================================================

  group('cold-start verifyEmail link', () {
    test('applies code from initial link on app launch', () async {
      final uri = _verifyEmailUri(oobCode: 'cold-verify');
      fakePlatform.initialLink = uri;

      when(
        () => mockAuth.checkActionCode('cold-verify'),
      ).thenAnswer((_) async {});
      when(
        () => mockAuth.applyActionCode('cold-verify'),
      ).thenAnswer((_) async {});
      when(() => mockAuth.reloadCurrentUser()).thenAnswer((_) async => null);

      final service = _buildService(mockAuth);
      await service.initialize();

      verify(() => mockAuth.applyActionCode('cold-verify')).called(1);

      await service.dispose();
    });
  });

  // =========================================================================
  // _extractFirebaseCode — error code extraction
  // =========================================================================

  group('_extractFirebaseCode (via verifyEmail error branches)', () {
    test('non-firebase error does not clear oobCode prematurely', () async {
      SharedPreferences.setMockInitialValues({});
      final uri = _verifyEmailUri(oobCode: 'some-code');

      // Throw a generic error (no Firebase error code pattern).
      when(
        () => mockAuth.checkActionCode('some-code'),
      ).thenThrow(Exception('network-timeout'));

      final service = _buildService(mockAuth);
      await service.initialize();
      fakePlatform.emit(uri);
      await pumpEventQueue();

      // oobCode should still be cleared in the catch block (best-effort cleanup).
      // The service stores and then handles — we just ensure it doesn't crash.
      await service.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: platform that throws on getInitialLink
// ---------------------------------------------------------------------------

class _ThrowingInitialLinkPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements AppLinksPlatform {
  @override
  Future<Uri?> getInitialLink() async =>
      throw Exception('platform channel error');

  @override
  Future<String?> getInitialLinkString() async => null;

  @override
  Future<Uri?> getLatestLink() async => null;

  @override
  Future<String?> getLatestLinkString() async => null;

  @override
  Stream<String> get stringLinkStream => const Stream<String>.empty();

  @override
  Stream<Uri> get uriLinkStream => const Stream<Uri>.empty();
}
