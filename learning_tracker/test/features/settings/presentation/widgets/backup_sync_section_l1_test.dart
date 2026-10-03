@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/firestore_sync_status_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

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

/// A [BackupLearningPort] whose replay result is scripted (DNI-482).
class _ScriptedPort implements BackupLearningPort {
  _ScriptedPort([
    this.result = const BackupReplayResult(result: CaptureResult.success()),
  ]);

  BackupReplayResult result;
  final List<String> retried = [];

  @override
  Future<List<LearningEvent>> readLearningEvents(String profileId) async =>
      const [];

  @override
  Future<List<SubTrack>> readSubTracks(String profileId) async => const [];

  @override
  Future<BackupReplayResult> replay(
    String profileId,
    BackupReplayInput input,
  ) async => result;

  @override
  Future<CaptureResult> retry(String profileId, String id) async {
    retried.add(id);
    return const CaptureResult.success();
  }
}

class _TrackingService extends DataExportImportService {
  _TrackingService(FakeFirebaseFirestore firestore, [BackupLearningPort? port])
    : super(
        firestore: firestore,
        learning: port ?? _ScriptedPort(),
        uid: testUid,
        appVersionFetcher: () async => 'widget-test',
      );

  bool importCalled = false;

  @override
  Future<BackupImportReport> importData(String jsonString) async {
    importCalled = true;
    return super.importData(jsonString);
  }
}

class _MockSnapshotMetadata extends Mock implements SnapshotMetadata {}

// ignore: subtype_of_sealed_class
class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

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
  Stream<FirestoreSyncStatus> Function(Ref ref)? syncStatusStreamFactory,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(_cloudAuthState),
      if (serviceState != null)
        dataExportImportServiceProvider.overrideWithValue(serviceState)
      else
        dataExportImportServiceProvider.overrideWith((ref) async => service),
      if (syncStatusStreamFactory != null)
        firestoreSyncStatusProvider.overrideWith(syncStatusStreamFactory),
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
      learning: _ScriptedPort(),
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

  testWidgets('a restore the server partly refused shows "not saved — retry" '
      'and Retry re-sends exactly those writes (DNI-482, AD-54)', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    const failure = PendingFailure(
      id: '01ARZ3NDEKTSV4RRFFQ69G5FAA',
      eventIds: ['01ARZ3NDEKTSV4RRFFQ69G5FAA'],
      changeIds: [],
      reason: PendingFailureReason.permissionDenied,
    );
    final port = _ScriptedPort(
      const BackupReplayResult(
        result: CaptureResult.success(),
        notSaved: [failure],
      ),
    );
    final service = _TrackingService(firestore, port);
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
    await tester.tap(find.text('Restore backup'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // snackbar enters

    expect(
      find.text('Not saved — part of the backup was not restored. Retry?'),
      findsOneWidget,
    );
    expect(find.text('Backup restored successfully.'), findsNothing);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await tester.pump();
    expect(port.retried, [failure.id]);
    await tester.pumpAndSettle();
  });

  testWidgets('a queued restore the server later refuses turns into "not '
      'saved — retry" (DNI-482, AD-54)', (tester) async {
    final firestore = await _seedFirestore();
    const failure = PendingFailure(
      id: '01ARZ3NDEKTSV4RRFFQ69G5FAA',
      eventIds: ['01ARZ3NDEKTSV4RRFFQ69G5FAA'],
      changeIds: [],
      reason: PendingFailureReason.permissionDenied,
    );
    final settled = Completer<void>();
    var isSettled = false;
    final failures = <PendingFailure>[];
    final port = _ScriptedPort(
      BackupReplayResult(
        result: const CaptureResult.success(),
        liveNotSaved: () => failures,
        isSettled: () => isSettled,
        settled: settled.future,
      ),
    );
    final service = _TrackingService(firestore, port);
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
    await tester.tap(find.text('Restore backup'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Backup restored successfully.'), findsOneWidget);

    failures.add(failure);
    isSettled = true;
    settled.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5)); // first snackbar times out
    await tester.pumpAndSettle(); // it leaves; the next one enters
    expect(
      find.text('Not saved — part of the backup was not restored. Retry?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
    await tester.pump();
    expect(port.retried, [failure.id]);
    await tester.pumpAndSettle();
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

  testWidgets('Firestore metadata with no pending writes shows Synced', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final statusStream = firestore
        .collection('users')
        .doc(testUid)
        .snapshots(includeMetadataChanges: true)
        .map(firestoreSyncStatusFromSnapshot);

    await tester.pumpWidget(
      _buildHarness(
        service: null,
        locale: const Locale('en'),
        syncStatusStreamFactory: (_) => statusStream,
      ),
    );
    await tester.pump();

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Syncing — pending changes'), findsNothing);
  });

  testWidgets('Hebrew sync status uses the localized Synced label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        service: null,
        locale: const Locale('he'),
        syncStatusStreamFactory: (_) =>
            Stream.value(FirestoreSyncStatus.synced),
      ),
    );
    await tester.pump();

    expect(find.text('מסונכרן'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
  });

  testWidgets('Firestore metadata with pending writes shows Syncing', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final metadata = _MockSnapshotMetadata();
    when(() => metadata.hasPendingWrites).thenReturn(true);
    when(() => metadata.isFromCache).thenReturn(true);
    final snapshot = _MockDocumentSnapshot();
    when(() => snapshot.metadata).thenReturn(metadata);

    await tester.pumpWidget(
      _buildHarness(
        service: null,
        locale: const Locale('en'),
        syncStatusStreamFactory: (_) =>
            Stream.value(firestoreSyncStatusFromSnapshot(snapshot)),
      ),
    );
    await tester.pump();

    expect(find.text('Syncing — pending changes'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    // Keep the fixture in this test: the status is still derived from the
    // same SDK snapshot metadata shape used by the live Firestore stream.
    expect(await firestore.collection('users').doc(testUid).get(), isNotNull);
  });

  testWidgets('terminal Firestore stream error shows Offline and Retry', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    var attempts = 0;

    await tester.pumpWidget(
      _buildHarness(
        service: null,
        locale: const Locale('en'),
        syncStatusStreamFactory: (_) {
          attempts += 1;
          return attempts == 1
              ? Stream<FirestoreSyncStatus>.error(
                  StateError('listener stopped'),
                  StackTrace.current,
                )
              : firestore
                    .collection('users')
                    .doc(testUid)
                    .snapshots()
                    .map(firestoreSyncStatusFromSnapshot);
        },
      ),
    );
    await tester.pump();

    expect(find.text('Offline — sync listener stopped'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Synced'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('Hebrew RTL renders backup actions and paste dialog', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = DataExportImportService(
      firestore: firestore,
      learning: _ScriptedPort(),
      uid: testUid,
    );
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

  testWidgets('empty preview shows validation and keeps the dialog open', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = DataExportImportService(
      firestore: firestore,
      learning: _ScriptedPort(),
      uid: testUid,
    );

    await tester.pumpWidget(
      _buildHarness(service: service, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview backup'));
    await tester.pump();

    expect(
      find.text('This backup is invalid or belongs to a different account.'),
      findsOneWidget,
    );
    expect(find.text('Paste backup'), findsOneWidget);
  });

  testWidgets('Cancel closes the paste dialog without validation feedback', (
    tester,
  ) async {
    final firestore = await _seedFirestore();
    final service = DataExportImportService(
      firestore: firestore,
      learning: _ScriptedPort(),
      uid: testUid,
    );

    await tester.pumpWidget(
      _buildHarness(service: service, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Paste backup'), findsNothing);
    expect(
      find.text('This backup is invalid or belongs to a different account.'),
      findsNothing,
    );
  });
}
