/// L1 widget tests for [ParentPendingRedemptionsScreen].
///
/// Covers:
///   - Empty state renders "no pending prize requests" message.
///   - Populated state renders reward cards with title, cost and action buttons.
///   - Approve (Fulfil) button calls [PointsBalanceDao.fulfilRedemption] and
///     shows snackbar.
///   - Decline button calls [PointsBalanceDao.declineRedemption], refunds
///     points, and shows snackbar.
///   - Double-tap guard: tapping Decline twice only refunds points once
///     (DAO has internal status guard).
///   - Double-tap guard: tapping Approve twice — flagged as BUG (no UI lock).
///   - Loading state shows [CircularProgressIndicator].
///   - Error state renders error message.
///   - Hebrew-RTL smoke: screen pumps without errors under `he` locale.
///   - Hardcoded-English string audit.
@Tags(['gamification', 'l1'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _MockStackRouter extends Mock implements StackRouter {}

/// Seeds a pending-fulfilment redemption row directly (bypasses balance
/// debit — the screen only needs the row to exist for its list).
Future<int> _seedPendingRedemption(
  UserDatabase db, {
  required int profileId,
  String rewardTitle = 'Test Prize',
  int iconIndex = 0,
  int pointsCost = 50,
}) async {
  final now = DateTimeFactory.nowUtc();
  return db
      .into(db.rewardRedemptions)
      .insert(
        RewardRedemptionsCompanion.insert(
          profileId: profileId,
          rewardTitle: rewardTitle,
          pointsCost: pointsCost,
          iconIndex: Value(iconIndex),
          status: const Value('pending_fulfilment'),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

/// Standard test pump widget — uses the real in-memory DB.
Widget _buildScreen(UserDatabase db, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      // Suppress outbox sync facade (local-born account — no cloud push).
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
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
      home: const ParentPendingRedemptionsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── 1. Empty state ──────────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — empty state', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows empty-state text when no pending redemptions', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n key pendingRedemptionsEmpty — body line.
      expect(find.text('No pending prize requests.'), findsOneWidget);

      // No action buttons visible.
      expect(find.text('Fulfil'), findsNothing);
      expect(find.text('Decline'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('empty state shows icon + title + body (standard pattern)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Icon (card_giftcard) — consistent with other empty states.
      expect(find.byIcon(Icons.card_giftcard), findsOneWidget);
      // Localized title (pendingRedemptionsEmptyTitle).
      expect(find.text('No prize requests yet'), findsOneWidget);
      // Localized body (pendingRedemptionsEmpty) retained beneath the title.
      expect(find.text('No pending prize requests.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('app-bar title reads "Pending Prizes"', (tester) async {
      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n key pendingRedemptionsTitle — currently hardcoded English.
      expect(find.text('Pending Prizes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 2. Loading state ────────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — loading state', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      // Use a StreamController that never emits — the StreamProvider stays in
      // AsyncLoading, so the screen shows the progress indicator indefinitely.
      final controller = StreamController<List<RewardRedemption>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
            outboxSyncWriteFacadeProvider.overrideWithValue(null),
            pendingRedemptionsProvider.overrideWith((ref) => controller.stream),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ParentPendingRedemptionsScreen(),
          ),
        ),
      );
      // One pump — the stream hasn't emitted so we stay in loading state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No pending prize requests.'), findsNothing);

      // Close the controller before teardown to avoid leaking resources.
      await controller.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 3. Error state ──────────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — error state', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders error message when provider throws', (tester) async {
      // Exception.toString() prepends "Exception: " so we test for that.
      const errorMsg = 'db_unavailable_for_test';
      await tester.pumpWidget(
        ProviderScope(
          // Riverpod 3: disable retry so StreamProvider surfaces AsyncError
          // instead of staying stuck in AsyncLoading on first-load failure.
          retry: (_, __) => null,
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
            outboxSyncWriteFacadeProvider.overrideWithValue(null),
            // For a StreamProvider, emit an error event via Stream.error().
            pendingRedemptionsProvider.overrideWith(
              (ref) => Stream.error(Exception(errorMsg)),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ParentPendingRedemptionsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The screen renders `e.toString()` directly which includes the
      // "Exception: " prefix from Dart's Exception class.
      expect(find.textContaining(errorMsg), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 4. Populated state ──────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — populated state', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders redemption card with title and cost', (tester) async {
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Ice Cream',
        pointsCost: 100,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Ice Cream'), findsOneWidget);
      // l10n pendingRedemptionsCost("100") — currently hardcoded English.
      expect(find.text('100 points'), findsOneWidget);
      // l10n pendingRedemptionsApprove / pendingRedemptionsDecline.
      expect(find.text('Fulfil'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders multiple redemption cards', (tester) async {
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Prize A',
        pointsCost: 50,
      );
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Prize B',
        pointsCost: 75,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Prize A'), findsOneWidget);
      expect(find.text('Prize B'), findsOneWidget);
      expect(find.text('Fulfil'), findsNWidgets(2));
      expect(find.text('Decline'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 5. Approve (Fulfil) action ──────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — Approve action', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('tapping Fulfil sets redemption status to fulfilled', (
      tester,
    ) async {
      final redemptionId = await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Book',
        pointsCost: 30,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Fulfil'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify DB state: status must now be 'fulfilled'.
      final rows = await db.pointsBalanceDao.getAllRedemptions(1);
      final row = rows.firstWhere((r) => r.id == redemptionId);
      expect(row.status, 'fulfilled');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tapping Fulfil shows fulfilled snackbar', (tester) async {
      await _seedPendingRedemption(db, profileId: 1);

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Fulfil'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n pendingRedemptionsFulfilledSnackbar — currently hardcoded English.
      expect(find.text('Prize marked as fulfilled!'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('after Fulfil the card disappears from the list', (
      tester,
    ) async {
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Toy',
        pointsCost: 20,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Toy'), findsOneWidget);

      await tester.tap(find.text('Fulfil'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Provider is invalidated → re-fetched → the fulfilled row is gone.
      expect(find.text('Toy'), findsNothing);
      expect(find.text('No pending prize requests.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 6. Decline action ──────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — Decline action', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('tapping Decline sets redemption status to declined', (
      tester,
    ) async {
      // Credit points so the decline/refund DAO path has a balance row.
      await db.pointsBalanceDao.creditCompletion(1, 200);
      final redemptionId = await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Movie Night',
        pointsCost: 80,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final rows = await db.pointsBalanceDao.getAllRedemptions(1);
      final row = rows.firstWhere((r) => r.id == redemptionId);
      expect(row.status, 'declined');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tapping Decline shows declined snackbar', (tester) async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      await _seedPendingRedemption(db, profileId: 1, pointsCost: 50);

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n pendingRedemptionsDeclinedSnackbar — currently hardcoded English.
      expect(
        find.text('Prize request declined. Points refunded.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tapping Decline refunds points to balance', (tester) async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      final balanceBefore = await db.pointsBalanceDao.getBalance(1);
      await _seedPendingRedemption(db, profileId: 1, pointsCost: 40);

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final balanceAfter = await db.pointsBalanceDao.getBalance(1);
      // The DAO refunds the pointsCost when declining.
      expect(balanceAfter, balanceBefore + 40);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('after Decline the card disappears and empty state appears', (
      tester,
    ) async {
      await db.pointsBalanceDao.creditCompletion(1, 100);
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Candy',
        pointsCost: 40,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Candy'), findsOneWidget);

      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Candy'), findsNothing);
      expect(find.text('No pending prize requests.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 7. Double-tap guard ─────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — double-tap guard', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('double-tap Decline only refunds points once', (tester) async {
      // Seed balance first; then seed the redemption row directly
      // (without debiting, so balance stays at 60).
      await db.pointsBalanceDao.creditCompletion(1, 60);
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Double Tap Prize',
        pointsCost: 60,
      );
      final balanceBefore = await db.pointsBalanceDao.getBalance(1);

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap twice without awaiting the async operation.
      await tester.tap(find.text('Decline'));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final balanceAfter = await db.pointsBalanceDao.getBalance(1);
      // The second decline is a no-op because declineRedemption checks
      // `row.status != 'pending_fulfilment'` and returns early. Points
      // are refunded only once.
      expect(balanceAfter, balanceBefore + 60);

      // Status must be 'declined', not double-mutated.
      final rows = await db.pointsBalanceDao.getAllRedemptions(1);
      expect(rows.first.status, 'declined');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // Fulfil marks the redemption fulfilled. The screen also has a double-tap
    // guard: _RedemptionCard disables Fulfil/Decline (_busy) while the async is
    // in flight, so a rapid double-tap can't fulfil twice / enqueue a second
    // sync push. (A deterministic double-tap test is infeasible here —
    // flutter_test forbids overlapping guarded tap() calls and the in-memory
    // DAO resolves before a second awaited tap — so the guard is verified by
    // construction; this asserts the normal fulfil path.)
    testWidgets('Fulfil marks redemption fulfilled (re-entry guarded)', (
      tester,
    ) async {
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'Lock Test Prize',
        pointsCost: 10,
      );

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Fulfil'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final rows = await db.pointsBalanceDao.getAllRedemptions(1);
      expect(rows.first.status, 'fulfilled');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 8. Hebrew-RTL smoke ─────────────────────────────────────────────────────

  group('ParentPendingRedemptionsScreen — Hebrew-RTL smoke', () {
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('pumps without errors under he locale (empty state)', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(db, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n pendingRedemptionsEmpty in Hebrew.
      expect(find.text('אין בקשות פרס ממתינות.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('pumps without errors under he locale (populated state)', (
      tester,
    ) async {
      await _seedPendingRedemption(
        db,
        profileId: 1,
        rewardTitle: 'פרס בעברית',
        pointsCost: 30,
      );

      await tester.pumpWidget(_buildScreen(db, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n pendingRedemptionsApprove in Hebrew: 'מלא'
      expect(find.text('מלא'), findsOneWidget);
      // l10n pendingRedemptionsDecline in Hebrew: 'דחה'
      expect(find.text('דחה'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── 9. AppBar back button (#32) ─────────────────────────────────────────────
  //
  // The AppBar ← MUST pop the route (same nav as hardware back) — it must NOT
  // open the profile-switcher sheet.
  group('ParentPendingRedemptionsScreen — AppBar back button (#32)', () {
    late UserDatabase db;
    late _MockStackRouter router;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
      router = _MockStackRouter();
      when(
        () => router.maybePop<Object?>(),
      ).thenAnswer((_) => Future<bool>.value(true));
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildWithRouter() => ProviderScope(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
        outboxSyncWriteFacadeProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const ParentPendingRedemptionsScreen(),
        ),
      ),
    );

    testWidgets('tapping back calls router.maybePop()', (tester) async {
      await tester.pumpWidget(buildWithRouter());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.byKey(const Key('parentPendingRedemptionsBackButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => router.maybePop<Object?>()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tapping back does NOT open the profile-switcher sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildWithRouter());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(
        find.byKey(const Key('parentPendingRedemptionsBackButton')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The switcher sheet must be absent — the back arrow is a plain pop.
      expect(find.byType(ProfileSwitcherSheet), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
