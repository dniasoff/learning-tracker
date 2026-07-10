// Regression test for AUD-account-01 (UI half): the Account Picker's
// swipe-to-remove flow for a cloud tile must surface the pending-outbox
// count and BLOCK removal before AccountLifecycleService.removeCloudFromDevice
// is ever invoked, instead of silently deleting a DB file that still holds
// undrained outbox rows.
// See: docs/audits/standards-audit-2026-07-03/delivery/findings/AUD-account-01.json
//
// BUG LOG:
//   - RED (pre-fix): _confirmDismiss had no outbox check at all, so tapping
//     "Remove" always returned true and Dismissible proceeded straight to
//     _onDismissed -> service.removeCloudFromDevice (which, pre-fix, deleted
//     the DB file unconditionally).
@Tags(['needs_flutter', 'account', 'multi_account'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/screens/account_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show SelectedProfileId, selectedProfileIdProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;
  @override
  AuthState build() => _initial;
}

class _StubSelectedProfileId extends SelectedProfileId {
  @override
  int? build() => null;
}

const _kTestDocsDir = '/tmp/flutter_test_account_picker_outbox_guard';

void _installPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async {
          switch (call.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
              return _kTestDocsDir;
            default:
              return null;
          }
        },
      );
}

final _kNow = DateTime.utc(2026, 1, 1);

Future<Widget> _buildSubject({required DeviceRegistryDatabase registry}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(null);
  final userDb = UserDatabase(NativeDatabase.memory());
  addTearDown(userDb.close);

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      deviceRegistryProvider.overrideWithValue(registry),
      authRepositoryProvider.overrideWithValue(auth),
      userDatabaseProvider.overrideWith((ref) => userDb),
      syncOrchestratorProvider.overrideWithValue(null),
      authStateProvider.overrideWith(
        () => _StubAuthStateNotifier(const AuthState.signedOut()),
      ),
      selectedProfileIdProvider.overrideWith(() => _StubSelectedProfileId()),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AccountPickerScreen(),
    ),
  );
}

void main() {
  setUpAll(_installPathProviderMock);

  setUp(() {
    final dir = Directory(_kTestDocsDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  });

  tearDown(() {
    final dir = Directory(_kTestDocsDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets(
    'swiping a cloud tile with an undrained outbox blocks removal and '
    'surfaces the pending count instead of deleting the DB file',
    (tester) async {
      const dbFileName = 'user_acc_outbox_guard.db';
      final driftFile = File('$_kTestDocsDir/$dbFileName.sqlite');

      // Seed the account's own user DB with one undrained outbox row.
      final seedDb = UserDatabase(NativeDatabase(driftFile));
      await seedDb
          .into(seedDb.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: 1,
              entityKind: 'completion',
              entityKey: 'k-1',
              payload: '{}',
              createdAt: _kNow,
            ),
          );
      await seedDb.close();

      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      await registry
          .into(registry.deviceAccounts)
          .insert(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-outbox-guard',
              email: 'guard@example.test',
              displayName: 'Guard User',
              tier: 'cloudBorn',
              firebaseUid: const Value('fb-uid-guard'),
              dbFileName: dbFileName,
              createdAt: _kNow,
              lastUsedAt: _kNow,
            ),
          );

      await tester.pumpWidget(await _buildSubject(registry: registry));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Guard User'), findsOneWidget);

      // Swipe to trigger the confirm dialog.
      await tester.drag(find.text('Guard User'), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Remove from device?'), findsOneWidget);

      // Tap "Remove" — this used to go straight through to deletion.
      await tester.tap(find.text('Remove'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // The pending-sync warning must appear instead of the tile vanishing.
      expect(find.text('Not backed up yet'), findsOneWidget);
      expect(
        find.text(
          "1 change hasn't been backed up to the cloud yet. Connect to "
          'the internet, wait for sync to finish, then try again.',
        ),
        findsOneWidget,
      );

      // Dismiss the warning.
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The tile is still present — removal was blocked.
      expect(find.text('Guard User'), findsOneWidget);

      // The DB file (and its one unsynced row) must survive.
      expect(
        driftFile.existsSync(),
        isTrue,
        reason: 'blocked removal must not delete the DB file',
      );
      final remaining = await registry.getAllAccounts();
      expect(
        remaining.map((a) => a.accountId),
        contains('acc-outbox-guard'),
        reason: 'blocked removal must not remove the registry row either',
      );

      await registry.close();
    },
  );

  testWidgets(
    'swiping a cloud tile with a fully-drained outbox proceeds to remove it '
    '(no happy-path regression)',
    (tester) async {
      const dbFileName = 'user_acc_outbox_clear.db';
      final driftFile = File('$_kTestDocsDir/$dbFileName.sqlite');

      // Real Drift DB, zero outbox rows.
      final seedDb = UserDatabase(NativeDatabase(driftFile));
      await seedDb.close();

      final registry = DeviceRegistryDatabase(NativeDatabase.memory());
      await registry
          .into(registry.deviceAccounts)
          .insert(
            DeviceAccountsCompanion.insert(
              accountId: 'acc-outbox-clear',
              email: 'clear@example.test',
              displayName: 'Clear User',
              tier: 'cloudBorn',
              firebaseUid: const Value('fb-uid-clear'),
              dbFileName: dbFileName,
              createdAt: _kNow,
              lastUsedAt: _kNow,
            ),
          );

      await tester.pumpWidget(await _buildSubject(registry: registry));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Clear User'), findsOneWidget);

      await tester.drag(find.text('Clear User'), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Remove'));
      // Let confirmDismiss's async outbox check + Dismissible's removal
      // animation settle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // No pending-sync warning this time.
      expect(find.text('Not backed up yet'), findsNothing);
      // The tile is gone — removal proceeded.
      expect(find.text('Clear User'), findsNothing);

      expect(
        driftFile.existsSync(),
        isFalse,
        reason: 'a drained outbox must not block removal',
      );

      await registry.close();
    },
  );
}
