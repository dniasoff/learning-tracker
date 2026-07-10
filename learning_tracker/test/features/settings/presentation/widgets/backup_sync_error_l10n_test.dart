// Regression test for ST-4: Backup & Sync status template leaves raw English
// status remainder under Hebrew UI.
//
// SYMPTOM: When sync fails with a FirestorePermissionDeniedException, the
// BackupSyncSection renders the raw exception string verbatim via
// l10n.backupSyncError(e.toString()), so under Hebrew UI the card shows
// "שגיאת סנכרון: FirestorePermissionDeniedException: FirebaseFirestore/
// completions read [cloud_firestore/permission-denied]" — internal class name,
// Firestore collection path, and error code all visible to the user.
//
// Similarly, the SyncStatusDegraded "outbox has N row(s) stuck after 3+
// attempts" reason string is passed verbatim into the Hebrew template, leaking
// English into the Hebrew UI.
//
// ROOT CAUSE: BackupSyncSection passes SyncStatus.message (or degraded reason)
// directly into the l10n template placeholders without mapping to a friendly
// localized string first.
//
// FIX UNDER TEST:
//   - For SyncStatusError: strip the raw exception text and replace with a
//     friendly, localized "Cloud backup temporarily unavailable." message.
//   - For SyncStatusDegraded with a stuck-outbox reason: suppress the raw
//     English reason string; show a localized fallback that does not expose
//     internal outbox detail.
//
// TESTS:
//   L1. Error state: raw exception class name NOT rendered.
//   L2. Error state: renders a user-friendly sync-related message.
//   L3. Degraded (stuck outbox) state: raw "row(s) stuck" NOT rendered.
//   L4. Degraded (stuck outbox) state: renders a user-friendly message.

@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

const _kCloudUser = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud@test.com',
    displayName: 'Cloud User',
    firebaseUid: 'uid-cloud',
  ),
  tier: Tier.cloudBorn,
);

Widget _buildHarness({required SyncStatus syncStatus}) {
  final mockRouter = _MockStackRouter();
  when(() => mockRouter.push(any())).thenAnswer((_) async => null);
  when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
  when(() => mockRouter.canPop()).thenReturn(false);

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(_kCloudUser),
      syncStatusProvider.overrideWith((_) => syncStatus),
      syncIdentityStatusProvider.overrideWithValue(
        const SyncIdentityStatus.matched(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: const Scaffold(body: BackupSyncSection()),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // -------------------------------------------------------------------------
  // L1. Error state must NOT expose raw exception class name.
  // -------------------------------------------------------------------------
  testWidgets(
    'L1. Error state: raw Dart exception class name is not rendered in the UI',
    (tester) async {
      // AUD-sync-01 (EH-5): the raw exception text now lives only in the
      // non-user-facing debugDetail field — it must never reach the UI.
      const rawMessage =
          'FirestorePermissionDeniedException: FirebaseFirestore/'
          'completions read [cloud_firestore/permission-denied]';

      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            code: SyncErrorCode.permissionDenied,
            failedAt: DateTime.now().toUtc(),
            debugDetail: rawMessage,
          ),
        ),
      );

      expect(
        find.textContaining('FirestorePermissionDeniedException'),
        findsNothing,
        reason:
            'The raw Dart exception class name must not appear in the UI — '
            'it leaks internal implementation details to end users',
      );
      expect(
        find.textContaining('permission-denied'),
        findsNothing,
        reason: 'The raw Firestore error code must not appear in the UI',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // L2. Error state renders a friendly localized message.
  // -------------------------------------------------------------------------
  testWidgets(
    'L2. Error state: renders a user-friendly sync-related message instead',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            code: SyncErrorCode.permissionDenied,
            failedAt: DateTime.now().toUtc(),
            debugDetail:
                'FirestorePermissionDeniedException: FirebaseFirestore/'
                'completions read [cloud_firestore/permission-denied]',
          ),
        ),
      );

      // A friendly sync/backup-related message must be visible to the user.
      final syncText = find.textContaining(
        RegExp(
          '(sync|backup|cloud|unavailable|retry|error)',
          caseSensitive: false,
        ),
      );
      expect(
        syncText,
        findsWidgets,
        reason:
            'A friendly sync-related message must be shown so the user '
            'understands the issue without seeing internal error details',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // L3. Degraded (stuck outbox) state must NOT expose raw English reason.
  // -------------------------------------------------------------------------
  testWidgets(
    'L3. Degraded state: raw "row(s) stuck" English reason is not rendered',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.degraded(
            pendingChanges: 3,
            reason: 'outbox has 3 row(s) stuck after 3+ attempts',
          ),
        ),
      );

      expect(
        find.textContaining('row(s) stuck'),
        findsNothing,
        reason:
            'The raw English stuck-outbox reason must not be rendered — '
            'it leaks English into a potentially non-English UI and exposes '
            'internal outbox terminology to end users',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // L4. Degraded (stuck outbox) state renders a friendly message.
  // -------------------------------------------------------------------------
  testWidgets('L4. Degraded state: renders a user-friendly localized message', (
    tester,
  ) async {
    await _pump(
      tester,
      _buildHarness(
        syncStatus: const SyncStatus.degraded(
          pendingChanges: 3,
          reason: 'outbox has 3 row(s) stuck after 3+ attempts',
        ),
      ),
    );

    // The card must still communicate a sync issue to the user.
    final syncText = find.textContaining(
      RegExp(
        '(sync|backup|cloud|paused|pending|unavailable)',
        caseSensitive: false,
      ),
    );
    expect(
      syncText,
      findsWidgets,
      reason:
          'A friendly sync-related message must be shown in place of the '
          'raw English stuck-outbox reason',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
