// L1 widget tests for AchievementUnlockCelebration
//
// Covers:
//   • Empty newUnlocks → dialog does NOT appear
//   • Single unlock → dialog shows title (l10n), emoji, message with name+milestone+track
//   • Single unlock → continue/button tap dismisses dialog
//   • Single unlock → auto-close timer (5 s) dismisses dialog
//   • In-flight guard → second concurrent call is dropped; only one dialog open
//   • Multiple unlocks list → only the FIRST record's milestone title shown
//   • Hebrew (he) locale smoke — dialog renders without overflow/crash
//
// Protocol notes:
//   • _UnlockPartyDialog is private; tested via showForUnlockedMilestones.
//   • ConfettiWidget uses shouldLoop:true — pumpAndSettle would hang.
//     Use pump() + pump(Duration(seconds:N)) only.
//   • SharedPreferences.setMockInitialValues({}) in setUp so _donePrefix
//     writes do not touch the filesystem.

@Tags(['l1', 'gamification', 'achievement_unlock_celebration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

// ── Constants ──────────────────────────────────────────────────────────────────

const _kProfileId = 1;
const _kProfileName = 'Chaya';
const _kMilestoneTitle = 'Gold Star';

/// A minimal [ProfileModel] used to feed [selectedProfileProvider].
final _kProfile = ProfileModel(
  id: _kProfileId,
  accountId: 1,
  displayName: _kProfileName,
  mode: 'child',
  avatarIndex: 0,
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
);

/// A single [RewardUnlockRecord] for the tests.
RewardUnlockRecord _makeUnlock({
  String title = _kMilestoneTitle,
  int trackId = 1,
}) => RewardUnlockRecord(
  milestoneId: 'mid-001',
  profileId: _kProfileId,
  trackId: trackId,
  title: title,
  thresholdPoints: 100,
  pointsAtUnlock: 105,
  unlockedAt: DateTime.utc(2024, 5, 1),
);

// ── Harness ────────────────────────────────────────────────────────────────────

/// Builds a [ProviderScope]-wrapped [MaterialApp] that exposes a trigger
/// [ElevatedButton]. Tapping the button calls
/// [AchievementUnlockCelebration.showForUnlockedMilestones] with [unlocks].
///
/// The harness overrides:
///   • [userDatabaseProvider]  → in-memory [UserDatabase]
///   • [activeProfileIdProvider] → [_kProfileId]
///   • [selectedProfileProvider] → resolves to [_kProfile]
///
/// The DB is pre-seeded so [_resolveTrackLabel] queries don't crash; because
/// the test track id is 99 (not seeded), `getTrackById` returns null and
/// [_resolveTrackLabel] returns '' — which is what the dialog message uses.
Widget _buildHarness({
  required List<RewardUnlockRecord> unlocks,
  Locale locale = const Locale('en'),
  ProfileModel? profile,
}) {
  final db = createTestUserDatabase();
  // AUD-t-gamification-04: this raw UserDatabase is handed to
  // overrideWithValue below, not owned by the ProviderScope/widget tree, so
  // nothing else closes it -- close it explicitly.
  addTearDown(db.close);
  final resolvedProfile = profile ?? _kProfile;

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(_kProfileId),
      selectedProfileProvider.overrideWith(
        (_) => Future<ProfileModel?>.value(resolvedProfile),
      ),
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
      home: _TriggerPage(unlocks: unlocks),
    ),
  );
}

/// A simple Scaffold page that holds a Consumer so we have a [WidgetRef].
/// Tapping the "SHOW" button triggers the celebration.
class _TriggerPage extends ConsumerWidget {
  const _TriggerPage({required this.unlocks});
  final List<RewardUnlockRecord> unlocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('trigger'),
          onPressed: () =>
              AchievementUnlockCelebration.showForUnlockedMilestones(
                context: context,
                ref: ref,
                newUnlocks: unlocks,
              ),
          child: const Text('SHOW'),
        ),
      ),
    );
  }
}

// ── Teardown helper ────────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Test suite ─────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ── Empty list → no dialog ────────────────────────────────────────────────

  group('AchievementUnlockCelebration — empty list → no dialog', () {
    testWidgets(
      'showForUnlockedMilestones with empty list does not open any dialog',
      (tester) async {
        setViewSize(tester);
        await tester.pumpWidget(_buildHarness(unlocks: const []));
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // No Dialog / no celebration content.
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.text('Wow! Amazing!'),
          findsNothing,
          reason:
              'No dialog must appear when newUnlocks is empty (early-return guard)',
        );
        await _teardown(tester);
      },
    );
  });

  // ── Single unlock → dialog content ────────────────────────────────────────

  group('AchievementUnlockCelebration — single unlock → dialog content', () {
    testWidgets('dialog opens and shows l10n title "Wow! Amazing!"', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Wow! Amazing!'),
        findsOneWidget,
        reason: 'achievementsUnlockPartyTitle must be shown in the dialog',
      );
      await _teardown(tester);
    });

    testWidgets('dialog shows the party emoji 🎉', (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('🎉'),
        findsOneWidget,
        reason: 'The party emoji must appear as a Text widget in the dialog',
      );
      await _teardown(tester);
    });

    testWidgets('dialog shows the milestone title in the message', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Message: "Congratulations, Chaya! You unlocked Gold Star on your  track — keep going!"
      expect(
        find.textContaining(_kMilestoneTitle),
        findsAtLeastNWidgets(1),
        reason: 'The milestone title must appear in the dialog message',
      );
      await _teardown(tester);
    });

    testWidgets('dialog shows the profile display name in the message', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining(_kProfileName),
        findsAtLeastNWidgets(1),
        reason: 'The profile display name must appear in the dialog message',
      );
      await _teardown(tester);
    });

    testWidgets(
      'dialog uses name-fallback "friend" when selectedProfile returns null',
      (tester) async {
        setViewSize(tester);
        final db = createTestUserDatabase();
        // AUD-t-gamification-04: see the matching comment on _buildHarness
        // above.
        addTearDown(db.close);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, __) => null,
            overrides: [
              userDatabaseProvider.overrideWithValue(db),
              activeProfileIdProvider.overrideWithValue(_kProfileId),
              selectedProfileProvider.overrideWith(
                (_) => Future<ProfileModel?>.value(null),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: _TriggerPage(unlocks: []),
            ),
          ),
        );

        // Rebuild with the actual unlocks via a second pumpWidget call
        final db2 = createTestUserDatabase();
        addTearDown(db2.close);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, __) => null,
            overrides: [
              userDatabaseProvider.overrideWithValue(db2),
              activeProfileIdProvider.overrideWithValue(_kProfileId),
              selectedProfileProvider.overrideWith(
                (_) => Future<ProfileModel?>.value(null),
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
              home: _TriggerPage(unlocks: [_makeUnlock()]),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Name-fallback: "friend"
        expect(
          find.textContaining('friend'),
          findsAtLeastNWidgets(1),
          reason:
              'When selectedProfile returns null, the fallback name "friend" '
              'must appear in the message',
        );
        await _teardown(tester);
      },
    );

    testWidgets('dialog shows the continue button with l10n label', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text("Yay! Let's go!"),
        findsOneWidget,
        reason: 'achievementsUnlockPartyButton l10n text must appear',
      );
      expect(find.byType(FilledButton), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('dialog contains ConfettiWidget instances for animation', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Two ConfettiWidgets: one shower + one burst.
      // We verify via the Dialog wrapper being present and no crash.
      expect(find.byType(Dialog), findsOneWidget);
      await _teardown(tester);
    });
  });

  // ── Continue button dismisses dialog ─────────────────────────────────────

  group('AchievementUnlockCelebration — continue button dismisses', () {
    testWidgets('tapping the continue button closes the dialog (Navigator.pop)', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog is visible.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text("Yay! Let's go!"), findsOneWidget);

      // Tap the continue button.
      await tester.tap(find.text("Yay! Let's go!"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be gone.
      expect(
        find.byType(Dialog),
        findsNothing,
        reason:
            'Tapping the continue button must pop the dialog via Navigator.of(context).pop()',
      );
      await _teardown(tester);
    });
  });

  // ── Auto-close timer ──────────────────────────────────────────────────────

  group('AchievementUnlockCelebration — auto-close timer', () {
    testWidgets('dialog auto-dismisses after 5 seconds', (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog is visible.
      expect(find.byType(Dialog), findsOneWidget);

      // Advance time past the 5-second auto-close timer.
      // Timer fires Navigator.pop() at 5s; pop route transition takes ~300ms.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byType(Dialog),
        findsNothing,
        reason:
            'The auto-close Timer(5 s) must dismiss the dialog without any tap',
      );
      await _teardown(tester);
    });
  });

  // ── In-flight guard ───────────────────────────────────────────────────────

  group('AchievementUnlockCelebration — in-flight guard', () {
    testWidgets(
      'second call while dialog is open is ignored (only one dialog at a time)',
      (tester) async {
        setViewSize(tester);
        await tester.pumpWidget(_buildHarness(unlocks: [_makeUnlock()]));
        await tester.pump();

        // First tap — dialog opens.
        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(Dialog), findsOneWidget);

        // Second tap — should be dropped by the in-flight guard.
        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Still exactly one dialog (not two stacked).
        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason:
              '_celebrationInFlightProvider guard must prevent a second dialog '
              'from opening while the first is still showing',
        );

        // Clean up: dismiss the dialog.
        await tester.tap(find.text("Yay! Let's go!"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await _teardown(tester);
      },
    );
  });

  // ── Multiple unlock records → shows first record ──────────────────────────

  group('AchievementUnlockCelebration — multiple unlock records', () {
    testWidgets(
      'when multiple unlocks provided, shows only the first milestone title',
      (tester) async {
        setViewSize(tester);
        final firstUnlock = _makeUnlock(title: 'Bronze Star');
        final secondUnlock = _makeUnlock(title: 'Silver Star');
        await tester.pumpWidget(
          _buildHarness(unlocks: [firstUnlock, secondUnlock]),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('trigger')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(Dialog), findsOneWidget);

        // First milestone's title must appear.
        expect(
          find.textContaining('Bronze Star'),
          findsAtLeastNWidgets(1),
          reason:
              'showForUnlockedMilestones uses newUnlocks.first; "Bronze Star" '
              'must appear in the dialog message',
        );
        // Second milestone's title must NOT appear.
        expect(
          find.textContaining('Silver Star'),
          findsNothing,
          reason:
              'Only the first unlock record is shown; "Silver Star" must not appear',
        );

        // Dismiss.
        await tester.tap(find.text("Yay! Let's go!"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await _teardown(tester);
      },
    );
  });

  // ── Hebrew (he) locale smoke ──────────────────────────────────────────────

  group('AchievementUnlockCelebration — Hebrew locale smoke', () {
    testWidgets('he locale: dialog renders without overflow or crash', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildHarness(unlocks: [_makeUnlock()], locale: const Locale('he')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Key structural widgets must be present under RTL without exceptions.
      expect(find.byType(Dialog), findsOneWidget);

      // The button must exist; label is in Hebrew.
      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'Continue button must render in he locale',
      );

      // Dismiss.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _teardown(tester);
    });

    testWidgets('he locale: empty unlocks — no dialog, no crash', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildHarness(unlocks: const [], locale: const Locale('he')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Dialog), findsNothing);
      await _teardown(tester);
    });
  });
}
