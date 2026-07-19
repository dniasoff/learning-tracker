// Mixed unit + widget tests for:
//   lib/features/settings/presentation/utils/send_logs_service.dart
//   lib/features/settings/presentation/utils/account_actions.dart (supplement)
//
// send_logs_service coverage (0% baseline):
//   S1. uid == null → SnackBar with errorSendLogsMustBeSignedIn
//   S2. gateway == null → SnackBar with errorSendLogsNoGateway
//   S3. success path: pushDiagnosticLog called with correct uid + field shape
//   S4. success SnackBar contains entry count
//   S5. log window filter: only entries within 10 min are included
//   S6. exception path: SnackBar shows the fixed localized fallback, never
//       the raw exception (AUD-settings-07, EH-5/ST-4)
//   S6b. exception path under Hebrew locale: SnackBar shows only
//       ARB-sourced Hebrew text (AUD-settings-07)
//   S7. entries map: ts is ISO-8601, lvl is uppercase, msg present
//   S8. entry with exception field → 'exc' key present in payload
//   S9. entry with error field → 'err' key present in payload
//   S10. expires_at is 7 days after 'now'
//   S11. window_minutes is 10
//
// account_actions supplement (account_actions_test.dart does not cover):
//   A1. showDeleteLocalAccountFlow: non-localBorn auth state → exits immediately
//   A2. showDeleteLocalAccountFlow: localBorn → delete dialog shown
//   A3. showDeleteLocalAccountFlow: confirmed delete, registry lookup
//       throws → SnackBar shows the fixed localized fallback, never the
//       raw exception (AUD-settings-07, EH-5/ST-4)
//   A4. showDeleteLocalAccountFlow under Hebrew locale: same, ARB-sourced
//       Hebrew text only (AUD-settings-07)

@Tags(['l1', 'settings', 'settings_utils'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/utils/send_logs_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

/// AUD-settings-07: used to force showDeleteLocalAccountFlow's catch branch
/// (account_actions.dart) by making the registry lookup inside
/// SessionPersistenceService.resolveActiveAccountId throw.
class _MockDeviceRegistryDatabase extends Mock
    implements DeviceRegistryDatabase {}

// ─── A1/A2: stub AuthStateNotifiers for showDeleteLocalAccountFlow ────────────

/// Signed-out (non-localBorn) auth state — drives A1.
class _SignedOutAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

/// Signed-in, localBorn auth state — drives A2.
class _LocalBornAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedIn(
    user: AuthUser(
      profileId: 1,
      email: 'local@example.com',
      displayName: 'Local User',
    ),
    tier: Tier.localBorn,
  );
}

// ─── Minimal host for pumping dialogs/snackbars ───────────────────────────────

Widget _buildHost(Widget child, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    retry: (_, __) => null,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// A host that calls sendLogsToFirebase when the button is tapped.
class _SendLogsHost extends StatelessWidget {
  const _SendLogsHost({
    required this.logger,
    required this.gateway,
    required this.auth,
  });

  final AppLogger logger;
  final FirestoreGateway? gateway;
  final AuthRepository auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => sendLogsToFirebase(
          context: context,
          logger: logger,
          gateway: gateway,
          auth: auth,
        ),
        child: const Text('send'),
      ),
    );
  }
}

/// A host that calls showDeleteLocalAccountFlow when the button is tapped.
class _DeleteLocalAccountHost extends ConsumerWidget {
  const _DeleteLocalAccountHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => showDeleteLocalAccountFlow(context, ref),
        child: const Text('trigger-delete-local'),
      ),
    );
  }
}

/// Host for [_DeleteLocalAccountHost] with the given [authStateNotifier]
/// overriding [authStateProvider]. [extraOverrides] merges in additional
/// provider overrides (e.g. a throwing deviceRegistryProvider double).
Widget _buildDeleteLocalAccountHost({
  required AuthStateNotifier Function() authStateNotifier,
  Locale locale = const Locale('en'),
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      authStateProvider.overrideWith(authStateNotifier),
      ...extraOverrides,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _DeleteLocalAccountHost(),
    ),
  );
}

// ─── Teardown helper ─────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Test data helpers ────────────────────────────────────────────────────────

AppUser _user({String uid = 'uid-test'}) => AppUser(
  uid: uid,
  email: 'test@example.com',
  displayName: 'Test',
  emailVerified: true,
  providers: const ['password'],
);

/// Returns an [AppLogger] wrapping a real [Talker] seeded with [entries].
/// Each entry is a [TalkerLog] (which extends TalkerData).
AppLogger _buildLogger(List<TalkerLog> entries) {
  final talker = Talker(
    settings: TalkerSettings(enabled: true, useConsoleLogs: false),
  );
  for (final e in entries) {
    talker.logCustom(e);
  }
  return AppLogger(talker);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockAuthRepository auth;
  late _MockFirestoreGateway gateway;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    // Prevent PackageInfo.fromPlatform() from hanging in tests.
    PackageInfo.setMockInitialValues(
      appName: 'TestApp',
      packageName: 'com.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() {
    auth = _MockAuthRepository();
    gateway = _MockFirestoreGateway();
  });

  // ── S1: uid == null → SnackBar ─────────────────────────────────────────────

  testWidgets('S1: uid null → SnackBar with errorSendLogsMustBeSignedIn', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Must be signed in to send logs'), findsOneWidget);
    verifyNever(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    );

    await _teardown(tester);
  });

  // ── S2: gateway == null → SnackBar ────────────────────────────────────────

  testWidgets('S2: gateway null → SnackBar with errorSendLogsNoGateway', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());
    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: null, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // errorSendLogsNoGateway = 'Sync not available — account not linked to cloud'
    expect(find.textContaining('Sync not available'), findsOneWidget);
    verifyNever(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    );

    await _teardown(tester);
  });

  // ── S3: success path — pushDiagnosticLog called with correct uid + shape ──

  testWidgets(
    'S3: success path — pushDiagnosticLog called with correct uid and required fields',
    (tester) async {
      String? capturedUid;
      Map<String, dynamic>? capturedData;
      when(() => auth.currentUser).thenReturn(_user(uid: 'abc123'));
      when(
        () => gateway.pushDiagnosticLog(
          uid: any(named: 'uid'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        capturedUid = inv.namedArguments[const Symbol('uid')] as String;
        capturedData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
      });

      final logger = _buildLogger([]);

      await tester.pumpWidget(
        _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
      );
      await tester.pump();
      await tester.tap(find.text('send'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(capturedUid, equals('abc123'));
      expect(capturedData, isNotNull);
      expect(capturedData!.containsKey('version'), isTrue);
      expect(capturedData!.containsKey('window_minutes'), isTrue);
      expect(capturedData!.containsKey('entry_count'), isTrue);
      expect(capturedData!.containsKey('entries'), isTrue);
      expect(capturedData!.containsKey('expires_at'), isTrue);

      await _teardown(tester);
    },
  );

  // ── S4: success SnackBar contains entry count ─────────────────────────────

  testWidgets('S4: success SnackBar contains entry count', (tester) async {
    when(() => auth.currentUser).thenReturn(_user());
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});

    final now = DateTime.now().toUtc();
    final entries = [
      TalkerLog('msg-1', logLevel: LogLevel.info, time: now),
      TalkerLog('msg-2', logLevel: LogLevel.debug, time: now),
    ];
    final logger = _buildLogger(entries);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('2 entries'), findsOneWidget);

    await _teardown(tester);
  });

  // ── S5: log window filter — entries older than 10 min excluded ────────────

  testWidgets('S5: entries older than 10 min are excluded from payload', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());

    Map<String, dynamic>? capturedData;
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      capturedData =
          invocation.namedArguments[const Symbol('data')]
              as Map<String, dynamic>;
    });

    final now = DateTime.now().toUtc();
    final recent = TalkerLog(
      'recent-msg',
      logLevel: LogLevel.info,
      time: now.subtract(const Duration(minutes: 5)),
    );
    final old = TalkerLog(
      'old-msg',
      logLevel: LogLevel.info,
      time: now.subtract(const Duration(minutes: 15)),
    );
    final logger = _buildLogger([recent, old]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(capturedData, isNotNull);
    final entries = capturedData!['entries'] as List<dynamic>;
    // Only the recent entry falls within the 10-minute window.
    expect(entries.length, equals(1));
    expect(
      (entries.first as Map<String, dynamic>)['msg'],
      equals('recent-msg'),
    );

    await _teardown(tester);
  });

  // ── S6: exception path → SnackBar with errorSendLogsFailed ───────────────
  // AUD-settings-07 (EH-5/ST-4): errorSendLogsFailed is now a fixed,
  // already-localized fallback (no {error} placeholder) — the raw exception
  // must never reach the widget tree.

  testWidgets(
    'S6: gateway throws → SnackBar shows the localized friendly fallback, '
    'never the raw exception (AUD-settings-07)',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());
      when(
        () => gateway.pushDiagnosticLog(
          uid: any(named: 'uid'),
          data: any(named: 'data'),
        ),
      ).thenThrow(Exception('upload failed'));

      final logger = _buildLogger([]);

      await tester.pumpWidget(
        _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
      );
      await tester.pump();
      await tester.tap(find.text('send'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Failed to send logs. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('upload failed'),
        findsNothing,
        reason:
            'AUD-settings-07 (EH-5): the caught exception\'s raw message '
            'must never reach the widget tree — only ARB-sourced text may '
            'render.',
      );

      await _teardown(tester);
    },
  );

  testWidgets('S6b: gateway throws under Hebrew locale → SnackBar shows only '
      'ARB-sourced Hebrew text, never the raw exception (AUD-settings-07)', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenThrow(Exception('upload failed'));

    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(
        _SendLogsHost(logger: logger, gateway: gateway, auth: auth),
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('שליחת היומנים נכשלה. נסו שוב.'), findsOneWidget);
    expect(find.textContaining('upload failed'), findsNothing);

    await _teardown(tester);
  });

  // ── S7: entry mapping — ts ISO-8601, lvl uppercase, msg present ──────────

  testWidgets(
    'S7: entry mapping produces ts as ISO-8601, lvl uppercase, msg present',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());

      Map<String, dynamic>? capturedData;
      when(
        () => gateway.pushDiagnosticLog(
          uid: any(named: 'uid'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        capturedData =
            inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
      });

      final now = DateTime.now().toUtc();
      final entry = TalkerLog(
        'hello world',
        logLevel: LogLevel.info,
        time: now.subtract(const Duration(minutes: 1)),
      );
      final logger = _buildLogger([entry]);

      await tester.pumpWidget(
        _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
      );
      await tester.pump();
      await tester.tap(find.text('send'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(capturedData, isNotNull);
      final entries = capturedData!['entries'] as List<dynamic>;
      expect(entries, isNotEmpty);
      final e = entries.first as Map<String, dynamic>;
      // ts must be a valid ISO-8601 string
      expect(() => DateTime.parse(e['ts'] as String), returnsNormally);
      // lvl must be uppercase
      expect(e['lvl'], equals((e['lvl'] as String).toUpperCase()));
      // msg must be present and non-null
      expect(e.containsKey('msg'), isTrue);

      await _teardown(tester);
    },
  );

  // ── S8: entry with exception → 'exc' key ─────────────────────────────────

  testWidgets('S8: TalkerData with exception produces exc key in entry', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());

    Map<String, dynamic>? capturedData;
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((inv) async {
      capturedData =
          inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
    });

    final now = DateTime.now().toUtc();
    final entry = TalkerLog(
      'msg with exc',
      logLevel: LogLevel.error,
      exception: Exception('boom'),
      time: now.subtract(const Duration(minutes: 1)),
    );
    final logger = _buildLogger([entry]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(capturedData, isNotNull);
    final entries = capturedData!['entries'] as List<dynamic>;
    expect(entries, isNotEmpty);
    final firstEntry = entries.first as Map<String, dynamic>;
    expect(firstEntry.containsKey('exc'), isTrue);
    expect(firstEntry['exc'], contains('boom'));

    await _teardown(tester);
  });

  // ── S9: entry with error → 'err' key ─────────────────────────────────────

  testWidgets('S9: TalkerData with error produces err key in entry', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());

    Map<String, dynamic>? capturedData;
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((inv) async {
      capturedData =
          inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
    });

    final now = DateTime.now().toUtc();
    final entry = TalkerLog(
      'msg with err',
      logLevel: LogLevel.error,
      error: ArgumentError('bad arg'),
      time: now.subtract(const Duration(minutes: 1)),
    );
    final logger = _buildLogger([entry]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(capturedData, isNotNull);
    final entries = capturedData!['entries'] as List<dynamic>;
    expect(entries, isNotEmpty);
    final firstEntry = entries.first as Map<String, dynamic>;
    expect(firstEntry.containsKey('err'), isTrue);

    await _teardown(tester);
  });

  // ── S10: expires_at is ~7 days after now ─────────────────────────────────

  testWidgets('S10: expires_at is 7 days after the upload timestamp', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(_user());

    Map<String, dynamic>? capturedData;
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((inv) async {
      capturedData =
          inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
    });

    final beforeCall = DateTime.now().toUtc();
    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final afterCall = DateTime.now().toUtc();

    expect(capturedData, isNotNull);
    final expiresAt = DateTime.parse(
      capturedData!['expires_at'] as String,
    ).toUtc();
    // expires_at must be approximately 7 days from now (±5 seconds tolerance)
    final expectedMin = beforeCall.add(
      const Duration(days: 7) - const Duration(seconds: 5),
    );
    final expectedMax = afterCall.add(
      const Duration(days: 7) + const Duration(seconds: 5),
    );
    expect(
      expiresAt.isAfter(expectedMin) && expiresAt.isBefore(expectedMax),
      isTrue,
      reason: 'expires_at $expiresAt should be ~7 days from now',
    );

    await _teardown(tester);
  });

  // ── S11: window_minutes == 10 ─────────────────────────────────────────────

  testWidgets('S11: window_minutes field is 10 in the payload', (tester) async {
    when(() => auth.currentUser).thenReturn(_user());

    Map<String, dynamic>? capturedData;
    when(
      () => gateway.pushDiagnosticLog(
        uid: any(named: 'uid'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((inv) async {
      capturedData =
          inv.namedArguments[const Symbol('data')] as Map<String, dynamic>;
    });

    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(_SendLogsHost(logger: logger, gateway: gateway, auth: auth)),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(capturedData, isNotNull);
    expect(capturedData!['window_minutes'], equals(10));

    await _teardown(tester);
  });

  // ── A1: non-localBorn auth state → exits immediately ─────────────────────

  testWidgets('A1: showDeleteLocalAccountFlow — non-localBorn auth state exits '
      'immediately with no dialog shown', (tester) async {
    await tester.pumpWidget(
      _buildDeleteLocalAccountHost(
        authStateNotifier: () => _SignedOutAuthStateNotifier(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger-delete-local'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AlertDialog), findsNothing);

    await _teardown(tester);
  });

  // ── A2: localBorn → delete-confirmation dialog shown ─────────────────────

  testWidgets('A2: showDeleteLocalAccountFlow — localBorn auth state shows the '
      'delete-confirmation dialog', (tester) async {
    await tester.pumpWidget(
      _buildDeleteLocalAccountHost(
        authStateNotifier: () => _LocalBornAuthStateNotifier(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('trigger-delete-local'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // showDeleteAccountDialog's type-DELETE confirmation dialog is shown.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Dismiss via Cancel — this test only asserts the dialog appears; the
    // confirmed deletion path is covered by AccountLifecycleService and
    // AccountManagementService's own unit tests.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _teardown(tester);
  });

  // ── A3: confirmed delete, registry lookup throws → friendly SnackBar ─────
  // AUD-settings-07 (EH-5/ST-4): showDeleteLocalAccountFlow's catch block
  // interpolated the raw exception's toString() into errorDeleteAccountFailed.
  // Force the failure via SessionPersistenceService.resolveActiveAccountId's
  // registry.findById lookup and assert only the fixed ARB fallback renders.

  testWidgets(
    'A3: showDeleteLocalAccountFlow — confirmed delete, registry lookup '
    'throws → SnackBar shows the localized friendly fallback, never the '
    'raw exception (AUD-settings-07)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'last_active_account_id': 'acc-forced',
      });
      final mockRegistry = _MockDeviceRegistryDatabase();
      when(
        () => mockRegistry.findById(any()),
      ).thenThrow(Exception('test-forced registry lookup failure'));

      await tester.pumpWidget(
        _buildDeleteLocalAccountHost(
          authStateNotifier: () => _LocalBornAuthStateNotifier(),
          extraOverrides: [
            deviceRegistryProvider.overrideWithValue(mockRegistry),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger-delete-local'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Failed to delete account. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('test-forced registry lookup failure'),
        findsNothing,
        reason:
            'AUD-settings-07 (EH-5): the caught exception\'s raw message '
            'must never reach the widget tree — only ARB-sourced text may '
            'render.',
      );

      await _teardown(tester);
    },
  );

  testWidgets(
    'A4: showDeleteLocalAccountFlow under Hebrew locale — confirmed delete, '
    'registry lookup throws → SnackBar shows only ARB-sourced Hebrew text, '
    'never the raw exception (AUD-settings-07)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'last_active_account_id': 'acc-forced',
      });
      final mockRegistry = _MockDeviceRegistryDatabase();
      when(
        () => mockRegistry.findById(any()),
      ).thenThrow(Exception('test-forced registry lookup failure'));

      await tester.pumpWidget(
        _buildDeleteLocalAccountHost(
          authStateNotifier: () => _LocalBornAuthStateNotifier(),
          locale: const Locale('he'),
          extraOverrides: [
            deviceRegistryProvider.overrideWithValue(mockRegistry),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger-delete-local'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'מחיקת חשבון'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('מחיקת החשבון נכשלה. נסו שוב.'), findsOneWidget);
      expect(
        find.textContaining('test-forced registry lookup failure'),
        findsNothing,
      );

      await _teardown(tester);
    },
  );
}
