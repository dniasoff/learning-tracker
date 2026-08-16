// Mixed unit + widget tests for:
//   lib/features/settings/presentation/utils/send_logs_service.dart
//
// send_logs_service coverage (0% baseline):
//   S1. uid == null → SnackBar with errorSendLogsMustBeSignedIn
//   S2. repository unavailable → SnackBar with errorSendLogsNoGateway
//   S3. obsolete gateway uid-forwarding premise documented inline below
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

@Tags(['l1', 'settings', 'settings_utils'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/settings/data/repositories/firestore_diagnostic_log_repository_impl.dart';
import 'package:learning_tracker/features/settings/presentation/utils/send_logs_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker/talker.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDiagnosticLogRepository extends Mock
    implements FirestoreDiagnosticLogRepositoryAdapter {}

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
    required this.repository,
    required this.auth,
  });

  final AppLogger logger;
  final FirestoreDiagnosticLogRepositoryAdapter repository;
  final AuthRepository auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => sendLogsToFirebase(
          context: context,
          logger: logger,
          repository: repository,
          auth: auth,
        ),
        child: const Text('send'),
      ),
    );
  }
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
  late _MockDiagnosticLogRepository repository;

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
    repository = _MockDiagnosticLogRepository();
  });

  // ── S1: uid == null → SnackBar ─────────────────────────────────────────────

  testWidgets('S1: uid null → SnackBar with errorSendLogsMustBeSignedIn', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Must be signed in to send logs'), findsOneWidget);
    verifyNever(() => repository.pushLog(any<Map<String, dynamic>>()));

    await _teardown(tester);
  });

  // ── S2: repository unavailable → SnackBar ─────────────────────────────────

  testWidgets(
    'S2: repository unavailable → SnackBar with errorSendLogsNoGateway',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());
      final logger = _buildLogger([]);

      when(
        () => repository.pushLog(any<Map<String, dynamic>>()),
      ).thenThrow(const DiagnosticLogRepositoryNotReadyException());
      await tester.pumpWidget(
        _buildHost(
          _SendLogsHost(logger: logger, repository: repository, auth: auth),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('send'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // errorSendLogsNoGateway = 'Sync not available — account not linked to cloud'
      expect(find.textContaining('Sync not available'), findsOneWidget);
      verifyNever(() => repository.pushLog(any<Map<String, dynamic>>()));

      await _teardown(tester);
    },
  );

  // S3 was removed: the deleted FirestoreGateway accepted `uid` and `data`
  // as named arguments, while the current account-scoped adapter accepts only
  // the payload and obtains its uid from its construction-time account.
  // The remaining success/payload tests cover the current pushLog contract.

  // ── S4: success SnackBar contains entry count ─────────────────────────────

  testWidgets('S4: success SnackBar contains entry count', (tester) async {
    when(() => auth.currentUser).thenReturn(_user());
    when(
      () => repository.pushLog(any<Map<String, dynamic>>()),
    ).thenAnswer((_) async {});

    final now = DateTime.now().toUtc();
    final entries = [
      TalkerLog('msg-1', logLevel: LogLevel.info, time: now),
      TalkerLog('msg-2', logLevel: LogLevel.debug, time: now),
    ];
    final logger = _buildLogger(entries);

    await tester.pumpWidget(
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
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
    when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
      invocation,
    ) async {
      capturedData =
          invocation.positionalArguments.single as Map<String, dynamic>;
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
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
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
    'S6: repository throws → SnackBar shows the localized friendly fallback, '
    'never the raw exception (AUD-settings-07)',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());
      when(
        () => repository.pushLog(any<Map<String, dynamic>>()),
      ).thenThrow(Exception('upload failed'));

      final logger = _buildLogger([]);

      await tester.pumpWidget(
        _buildHost(
          _SendLogsHost(logger: logger, repository: repository, auth: auth),
        ),
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

  testWidgets(
    'S6b: repository throws under Hebrew locale → SnackBar shows only '
    'ARB-sourced Hebrew text, never the raw exception (AUD-settings-07)',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());
      when(
        () => repository.pushLog(any<Map<String, dynamic>>()),
      ).thenThrow(Exception('upload failed'));

      final logger = _buildLogger([]);

      await tester.pumpWidget(
        _buildHost(
          _SendLogsHost(logger: logger, repository: repository, auth: auth),
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
    },
  );

  // ── S7: entry mapping — ts ISO-8601, lvl uppercase, msg present ──────────

  testWidgets(
    'S7: entry mapping produces ts as ISO-8601, lvl uppercase, msg present',
    (tester) async {
      when(() => auth.currentUser).thenReturn(_user());

      Map<String, dynamic>? capturedData;
      when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
        inv,
      ) async {
        capturedData = inv.positionalArguments.single as Map<String, dynamic>;
      });

      final now = DateTime.now().toUtc();
      final entry = TalkerLog(
        'hello world',
        logLevel: LogLevel.info,
        time: now.subtract(const Duration(minutes: 1)),
      );
      final logger = _buildLogger([entry]);

      await tester.pumpWidget(
        _buildHost(
          _SendLogsHost(logger: logger, repository: repository, auth: auth),
        ),
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
    when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
      inv,
    ) async {
      capturedData = inv.positionalArguments.single as Map<String, dynamic>;
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
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
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
    when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
      inv,
    ) async {
      capturedData = inv.positionalArguments.single as Map<String, dynamic>;
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
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
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
    when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
      inv,
    ) async {
      capturedData = inv.positionalArguments.single as Map<String, dynamic>;
    });

    final beforeCall = DateTime.now().toUtc();
    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
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
    when(() => repository.pushLog(any<Map<String, dynamic>>())).thenAnswer((
      inv,
    ) async {
      capturedData = inv.positionalArguments.single as Map<String, dynamic>;
    });

    final logger = _buildLogger([]);

    await tester.pumpWidget(
      _buildHost(
        _SendLogsHost(logger: logger, repository: repository, auth: auth),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(capturedData, isNotNull);
    expect(capturedData!['window_minutes'], equals(10));

    await _teardown(tester);
  });
}
