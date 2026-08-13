@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _cloudAuthState = AuthState.signedIn(
  user: AuthUser(
    uid: testUid,
    email: 'backup@test.com',
    displayName: 'Backup User',
    firebaseUid: testUid,
  ),
  tier: Tier.cloud,
);

class _RecordingDelivery implements BackupFileDelivery {
  String? json;

  @override
  Future<void> share(String value) async => json = value;
}

class _TrackingService extends DataExportImportService {
  _TrackingService(FakeFirebaseFirestore firestore)
    : super(
        firestore: firestore,
        uid: testUid,
        appVersionFetcher: () async => 'widget-test',
      );

  bool importCalled = false;

  @override
  Future<void> importData(String jsonString) async {
    importCalled = true;
    await super.importData(jsonString);
  }
}

Future<FakeFirebaseFirestore> _seedFirestore() async {
  final firestore = FakeFirebaseFirestore();
  await seedAccount(firestore, uid: testUid);
  await seedProfile(firestore, uid: testUid, profileId: testProfileId);
  return firestore;
}

Widget _buildHarness({
  required DataExportImportService? service,
  required Locale locale,
  BackupFileDelivery? delivery,
  AsyncValue<DataExportImportService?>? serviceState,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(_cloudAuthState),
      if (serviceState != null)
        dataExportImportServiceProvider.overrideWithValue(serviceState)
      else
        dataExportImportServiceProvider.overrideWith((ref) async => service),
      if (delivery != null)
        backupFileDeliveryProvider.overrideWithValue(delivery),
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
      home: const Scaffold(body: BackupSyncSection()),
    ),
  );
}

void main() {
  testWidgets('export action calls service and shares the generated JSON', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = DataExportImportService(
      firestore: firestore,
      uid: testUid,
      appVersionFetcher: () async => 'widget-test',
    );
    final delivery = _RecordingDelivery();

    await tester.pumpWidget(
      _buildHarness(
        service: service,
        delivery: delivery,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();

    expect(delivery.json, isNotNull);
    final exported = jsonDecode(delivery.json!) as Map<String, dynamic>;
    expect(exported['version'], DataExportImportService.formatVersion);
    expect(find.text('Backup is ready to share.'), findsOneWidget);
  });

  testWidgets('import previews the backup and waits for confirmation', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = _TrackingService(firestore);
    final json = await service.exportData();

    await tester.pumpWidget(
      _buildHarness(service: service, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import backup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), json);
    await tester.tap(find.text('Preview backup'));
    await tester.pumpAndSettle();

    expect(find.text('Review backup before restoring'), findsOneWidget);
    expect(find.textContaining('This backup contains'), findsOneWidget);
    expect(find.text('Restore backup'), findsOneWidget);
    expect(service.importCalled, isFalse);

    await tester.tap(find.text('Restore backup'));
    await tester.pumpAndSettle();
    expect(service.importCalled, isTrue);
  });

  testWidgets('service error renders the app error state', (tester) async {
    final error = StateError('test provider failure');
    await tester.pumpWidget(
      _buildHarness(
        service: null,
        serviceState: AsyncError<DataExportImportService>(
          error,
          StackTrace.current,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('Hebrew RTL renders backup actions and paste dialog', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = DataExportImportService(firestore: firestore, uid: testUid);
    await tester.pumpWidget(
      _buildHarness(service: service, locale: const Locale('he')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ייצוא גיבוי'), findsOneWidget);
    expect(find.text('ייבוא גיבוי'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ייבוא גיבוי'));
    await tester.pumpAndSettle();
    expect(find.text('הדבקת גיבוי'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
