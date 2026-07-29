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
// AUD-settings-01: the identity-mismatch branch of _buildDegradedCard has its
// own separate leak — when `syncIdentityStatusProvider` reports a mismatch,
// the card renders sync_orchestrator's hand-built English sentence
// ("Signed in as x@... — sign in as y@... to back up this account.")
// verbatim as the subtitle, bypassing AppLocalizations entirely. This is
// invisible to L1-L4 because _buildHarness hardcodes
// `SyncIdentityStatus.matched()` in every test.
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
//   - For SyncStatusDegraded with an identity mismatch: build the subtitle
//     entirely from AppLocalizations (never the raw orchestrator reason
//     string), so a Hebrew-locale user never sees an English sentence.
//
// TESTS:
//   L1. Error state: raw exception class name NOT rendered.
//   L2. Error state: renders a user-friendly sync-related message.
//   L3. Degraded (stuck outbox) state: raw "row(s) stuck" NOT rendered.
//   L4. Degraded (stuck outbox) state: renders a user-friendly message.
//   L5. Degraded (identity mismatch) state, under Hebrew locale: raw English
//       "Signed in as" reason fragment NOT rendered; localized Hebrew
//       fallback IS rendered.

@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

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

Widget _buildHarness({
  required SyncStatus syncStatus,
  SyncIdentityStatus identityStatus = const SyncIdentityStatus.matched(),
  Locale? locale,
}) {
  final mockRouter = _MockStackRouter();
  when(() => mockRouter.push(any())).thenAnswer((_) async => null);
  when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
  when(() => mockRouter.canPop()).thenReturn(false);

  return pumpApp(
    // pumpApp's `locale` is non-nullable (defaults to Locale('en')); this
    // harness's own `locale` stays nullable so callers can omit it exactly
    // as before, falling back to the same English default.
    locale: locale ?? const Locale('en'),
    overrides: [
      authStateProvider.overrideWithValue(_kCloudUser),
      syncStatusProvider.overrideWith((_) => syncStatus),
      syncIdentityStatusProvider.overrideWithValue(identityStatus),
    ],
    child: StackRouterScope(
      controller: mockRouter,
      stateHash: 0,
      child: const Scaffold(body: BackupSyncSection()),
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
            failedAt: DateTimeFactory.nowUtc(),
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
            failedAt: DateTimeFactory.nowUtc(),
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

  // -------------------------------------------------------------------------
  // L5. Degraded (identity mismatch) state under Hebrew locale must NOT
  // expose the raw English orchestrator sentence.
  // -------------------------------------------------------------------------
  testWidgets(
    'L5. Degraded identity-mismatch state under Hebrew locale: raw English '
    '"Signed in as" reason is not rendered; localized Hebrew text is',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.degraded(
            pendingChanges: 2,
            // The exact raw sentence sync_orchestrator.dart builds for an
            // identity mismatch (see _skipPullOnIdentityMismatch /
            // _recomputeOutboxStatus). If the widget ever falls back to
            // rendering this verbatim, L5 must catch it.
            reason:
                'Signed in as wrong@test.com — sign in as '
                'active@test.com to back up this account.',
          ),
          identityStatus: const SyncIdentityStatus.mismatched(
            activeAccountEmail: 'active@test.com',
            signedInEmail: 'wrong@test.com',
          ),
          locale: const Locale('he'),
        ),
      );

      expect(
        find.textContaining('Signed in as'),
        findsNothing,
        reason:
            'The raw English identity-mismatch reason built by '
            'sync_orchestrator must not be rendered under a Hebrew locale — '
            'it leaks English into the Hebrew UI (AUD-settings-01)',
      );
      expect(
        find.textContaining('back up this account'),
        findsNothing,
        reason:
            'No fragment of the raw English orchestrator sentence may leak '
            'through, even if only part of it is reused verbatim',
      );

      // A localized Hebrew message must still be visible so the user
      // understands sync is paused and can act on it.
      final hebrewText = find.textContaining(
        RegExp('[֐-׿]'), // any Hebrew-block character
      );
      expect(
        hebrewText,
        findsWidgets,
        reason:
            'A localized Hebrew message must replace the raw English '
            'identity-mismatch reason',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // -------------------------------------------------------------------------
  // D1–D3. Card copy is differentiated by SyncErrorCode (1.0.67 App Check
  // incident). A PERMANENT failure (appCheck / permissionDenied) must NOT read
  // as "temporarily … tap to retry"; a TRANSIENT failure (timeout) keeps it.
  // -------------------------------------------------------------------------
  testWidgets(
    'D1. appCheck error renders NON-transient copy — no "temporarily", no '
    '"Tap to retry"',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            code: SyncErrorCode.appCheck,
            failedAt: DateTimeFactory.nowUtc(),
            debugDetail:
                '[cloud_firestore/permission-denied] App Check token is '
                'invalid: Too many attempts.',
          ),
        ),
      );

      expect(
        find.textContaining('temporarily'),
        findsNothing,
        reason:
            'A permanent App Check failure must not be framed as temporary — '
            'retrying the same pull can never succeed (1.0.67 incident).',
      );
      expect(
        find.textContaining('Tap to retry'),
        findsNothing,
        reason:
            'A permanent App Check failure must not invite a doomed retry loop.',
      );
      // A non-transient, app-verification-oriented message IS shown.
      expect(find.textContaining('verify this app'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'D2. permissionDenied error renders NON-transient copy — no "temporarily", '
    'no "Tap to retry"',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            code: SyncErrorCode.permissionDenied,
            failedAt: DateTimeFactory.nowUtc(),
            debugDetail: 'FirestorePermissionDeniedException: rules rejected',
          ),
        ),
      );

      expect(find.textContaining('temporarily'), findsNothing);
      expect(find.textContaining('Tap to retry'), findsNothing);
      // The permanent "unavailable for this account" copy IS shown.
      expect(
        find.textContaining('unavailable for this account'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'D3. timeout error keeps the TRANSIENT "temporarily … tap to retry" copy',
    (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            code: SyncErrorCode.timeout,
            failedAt: DateTimeFactory.nowUtc(),
            debugDetail: 'TimeoutException after 0:00:08.000000',
          ),
        ),
      );

      expect(
        find.textContaining('temporarily'),
        findsOneWidget,
        reason: 'A timeout IS transient — retry framing is correct here.',
      );
      expect(find.textContaining('Tap to retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
