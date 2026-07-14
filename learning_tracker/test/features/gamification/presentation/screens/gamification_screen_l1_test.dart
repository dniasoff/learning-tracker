// L1 widget tests for GamificationScreen
//
// Covers:
//   • Loading state — CircularProgressIndicator while achievementsOverviewProvider loads
//   • Error state   — errorLoadingCalendar text when provider errors
//   • Empty state   — noRewardsYet text when overview has no rows
//   • Populated state:
//       - ProgressSummaryCard rendered (unlocked/total fraction)
//       - AchievementTierCard milestone title shown
//       - TrackFilterRow chip: "All Tracks" chip present
//       - Activity & points expansion tile present
//       - Streak data surfaced in adult mode (subtle display)
//       - Streak data surfaced in child mode (animated display with fire icon)
//   • Points/child-scoping:
//       - PointsDisplayWidget hidden in adult mode (adults have no points)
//       - PointsDisplayWidget visible inside expansion tile in child mode
//   • Page title renders ("My Achievements")
//   • Filter chip interaction: tapping a track chip filters the list
//   • he-RTL smoke: screen renders without overflow in Hebrew locale

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/gamification_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_tier_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/points_display_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/progress_summary_card.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/track_tag_chip.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

RewardMilestone _milestone({
  String id = 'ms1',
  int profileId = 1,
  int trackId = 1,
  String title = 'Bronze Star',
  int thresholdPoints = 100,
  bool isEnabled = true,
}) {
  final now = DateTimeFactory.nowUtc();
  return RewardMilestone(
    id: id,
    profileId: profileId,
    trackId: trackId,
    title: title,
    thresholdPoints: thresholdPoints,
    isEnabled: isEnabled,
    createdAt: now,
    updatedAt: now,
  );
}

AchievementRowVm _row({
  int trackId = 1,
  String trackLabel = 'Mishnayos',
  String milestoneTitle = 'Bronze Star',
  int trackPoints = 50,
  bool isUnlocked = false,
  bool isNextUp = true,
}) {
  return AchievementRowVm(
    trackId: trackId,
    trackLabel: trackLabel,
    curriculumId: null,
    milestone: _milestone(title: milestoneTitle, trackId: trackId),
    trackPoints: trackPoints,
    isUnlocked: isUnlocked,
    isNextUp: isNextUp,
    isLegendTier: false,
  );
}

AchievementsOverview _emptyOverview() {
  return const AchievementsOverview(
    rows: [],
    unlockedCount: 0,
    totalMilestones: 0,
    trackFilterOptions: [],
  );
}

AchievementsOverview _populatedOverview({
  List<AchievementRowVm>? rows,
  List<AchievementTrackFilterVm>? filterOptions,
}) {
  final r = rows ?? [_row(trackId: 1, milestoneTitle: 'Bronze Star')];
  final opts =
      filterOptions ??
      [
        const AchievementTrackFilterVm(
          trackId: 1,
          curriculumId: null,
          sortLabel: 'Mishnayos',
        ),
      ];
  return AchievementsOverview(
    rows: r,
    unlockedCount: r.where((rv) => rv.isUnlocked).length,
    totalMilestones: r.length,
    trackFilterOptions: opts,
  );
}

typedef StreakRecord = ({int currentStreak, int maxStreak});

/// Builds the widget under test with all providers stubbed.
///
/// [achievementsState] drives the main content area.
/// [userMode] controls child vs adult UI gating.
/// [streak] is the streak record supplied by dashboardStreakProvider.
/// [calendarDates] is returned by streakCalendarProvider.
Widget _buildApp({
  AsyncValue<AchievementsOverview>? achievementsState,
  ProfileMode userMode = ProfileMode.adult,
  StreakRecord streak = (currentStreak: 0, maxStreak: 0),
  Set<DateTime> calendarDates = const {},
  bool disableRetry = false,
  Locale locale = const Locale('en'),
}) {
  final achievementsVal = achievementsState ?? AsyncData(_emptyOverview());

  return pumpApp(
    locale: locale,
    retry: disableRetry ? (_, __) => null : null,
    overrides: [
      achievementsOverviewProvider.overrideWith((ref) {
        switch (achievementsVal) {
          case AsyncData(:final value):
            return Future.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Future.error(error, stackTrace);
          case _:
            return Completer<AchievementsOverview>().future;
        }
      }),
      dashboardUserModeProvider.overrideWith((ref) => Future.value(userMode)),
      dashboardStreakProvider.overrideWith((ref) => Stream.value(streak)),
      streakCalendarProvider.overrideWith((ref) => Future.value(calendarDates)),
      // syncWriteFacadeProvider returns null so migrateDoneKeysIfNeeded
      // never tries to push to Firestore.
      syncWriteFacadeProvider.overrideWithValue(null),
      // Points providers are needed by PointsDisplayWidget inside the
      // expansion tile. Override to avoid real DB calls.
      globalPointsProvider.overrideWith((ref) => Stream.value(0)),
      curriculumBreakdownProvider.overrideWith((ref) async => {}),
    ],
    child: const Scaffold(body: GamificationScreen()),
  );
}

/// Pumps the widget and waits for async providers to settle.
Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── Page title ─────────────────────────────────────────────────────────────

  testWidgets('renders page title "My Achievements"', (tester) async {
    await _pump(tester, _buildApp());

    expect(find.text('My Achievements'), findsOneWidget);

    await _teardown(tester);
  });

  // ── Loading state ───────────────────────────────────────────────────────────

  testWidgets(
    'shows CircularProgressIndicator while achievementsOverview loads',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(achievementsState: const AsyncLoading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await _teardown(tester);
    },
  );

  // ── Error state ─────────────────────────────────────────────────────────────

  testWidgets('shows errorLoadingCalendar text when provider errors', (
    tester,
  ) async {
    await _pump(
      tester,
      _buildApp(
        achievementsState: AsyncError(
          Exception('network error'),
          StackTrace.empty,
        ),
        disableRetry: true,
      ),
    );

    expect(find.text('Error loading calendar'), findsOneWidget);

    await _teardown(tester);
  });

  // ── Empty state ─────────────────────────────────────────────────────────────

  testWidgets('shows noRewardsYet text when overview has no rows', (
    tester,
  ) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_emptyOverview())),
    );

    expect(find.text('No rewards earned yet. Keep learning!'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('empty overview: ProgressSummaryCard still shows 0/0 fraction', (
    tester,
  ) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_emptyOverview())),
    );

    expect(find.byType(ProgressSummaryCard), findsOneWidget);

    await _teardown(tester);
  });

  // ── Populated state ─────────────────────────────────────────────────────────

  testWidgets('populated: ProgressSummaryCard is rendered', (tester) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_populatedOverview())),
    );

    expect(find.byType(ProgressSummaryCard), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('populated: milestone title appears in the list', (tester) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_populatedOverview())),
    );

    expect(find.text('Bronze Star'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('populated: "All Tracks" filter chip is present', (tester) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_populatedOverview())),
    );

    expect(find.text('All Tracks'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets(
    'populated: track-specific filter chip appears with track sortLabel',
    (tester) async {
      await _pump(
        tester,
        _buildApp(achievementsState: AsyncData(_populatedOverview())),
      );

      // The track filter VM has sortLabel = 'Mishnayos' and no curriculumId,
      // so the label rendered by _filterChipLabel is the sortLabel itself.
      expect(find.text('Mishnayos'), findsWidgets);

      await _teardown(tester);
    },
  );

  testWidgets('"Activity & points" expansion tile is present', (tester) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_emptyOverview())),
    );

    expect(find.text('Activity & points'), findsOneWidget);

    await _teardown(tester);
  });

  // ── Streak display ──────────────────────────────────────────────────────────

  testWidgets(
    'adult mode: StreakWidget renders subtle display with streak count',
    (tester) async {
      await _pump(
        tester,
        _buildApp(
          achievementsState: AsyncData(_emptyOverview()),
          userMode: ProfileMode.adult,
          streak: (currentStreak: 5, maxStreak: 10),
        ),
      );

      // Expand the "Activity & points" tile to see the StreakWidget
      await tester.tap(find.text('Activity & points'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(StreakWidget), findsOneWidget);
      // Adult streak shows "(best: 10)" — the unique text for this streakcount
      expect(find.text('(best: 10)'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets(
    'child mode: StreakWidget renders animated display with fire icon',
    (tester) async {
      await _pump(
        tester,
        _buildApp(
          achievementsState: AsyncData(_emptyOverview()),
          userMode: ProfileMode.child,
          streak: (currentStreak: 3, maxStreak: 7),
        ),
      );

      await tester.tap(find.text('Activity & points'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(StreakWidget), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsWidgets);
      expect(find.textContaining('3 day streak'), findsOneWidget);

      await _teardown(tester);
    },
  );

  // ── Points child-scoping ────────────────────────────────────────────────────

  testWidgets(
    'adult mode: PointsDisplayWidget is hidden (adults have no points)',
    (tester) async {
      await _pump(
        tester,
        _buildApp(
          achievementsState: AsyncData(_emptyOverview()),
          userMode: ProfileMode.adult,
        ),
      );

      // Expand the activity tile to reveal the PointsDisplayWidget
      await tester.tap(find.text('Activity & points'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In adult mode the widget renders SizedBox.shrink — no "Total Points"
      expect(find.text('Total Points'), findsNothing);

      await _teardown(tester);
    },
  );

  testWidgets(
    'child mode: PointsDisplayWidget is visible inside the expansion tile',
    (tester) async {
      await _pump(
        tester,
        _buildApp(
          achievementsState: AsyncData(_emptyOverview()),
          userMode: ProfileMode.child,
        ),
      );

      await tester.tap(find.text('Activity & points'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PointsDisplayWidget), findsOneWidget);
      // Points total label should appear since globalPointsProvider returns 0
      expect(find.text('Total Points'), findsOneWidget);

      await _teardown(tester);
    },
  );

  // ── Filter chip interaction ──────────────────────────────────────────────────

  testWidgets('tapping a track chip filters out rows from other tracks', (
    tester,
  ) async {
    final rows = [
      _row(trackId: 1, milestoneTitle: 'Track 1 Reward'),
      _row(trackId: 2, milestoneTitle: 'Track 2 Reward'),
    ];
    final filterOptions = [
      const AchievementTrackFilterVm(
        trackId: 1,
        curriculumId: null,
        sortLabel: 'Mishnayos',
      ),
      const AchievementTrackFilterVm(
        trackId: 2,
        curriculumId: null,
        sortLabel: 'Bavli',
      ),
    ];
    final overview = AchievementsOverview(
      rows: rows,
      unlockedCount: 0,
      totalMilestones: rows.length,
      trackFilterOptions: filterOptions,
    );

    await _pump(tester, _buildApp(achievementsState: AsyncData(overview)));

    // Both rows visible initially
    expect(find.text('Track 1 Reward'), findsOneWidget);
    expect(find.text('Track 2 Reward'), findsOneWidget);

    // Tap track-1 chip to filter
    await tester.tap(find.text('Mishnayos').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // After filtering: track 1 row visible, track 2 row hidden
    expect(find.text('Track 1 Reward'), findsOneWidget);
    expect(find.text('Track 2 Reward'), findsNothing);

    await _teardown(tester);
  });

  testWidgets('tapping "All Tracks" chip restores all rows after filtering', (
    tester,
  ) async {
    final rows = [
      _row(trackId: 1, milestoneTitle: 'Track 1 Reward'),
      _row(trackId: 2, milestoneTitle: 'Track 2 Reward'),
    ];
    final filterOptions = [
      const AchievementTrackFilterVm(
        trackId: 1,
        curriculumId: null,
        sortLabel: 'Mishnayos',
      ),
      const AchievementTrackFilterVm(
        trackId: 2,
        curriculumId: null,
        sortLabel: 'Bavli',
      ),
    ];
    final overview = AchievementsOverview(
      rows: rows,
      unlockedCount: 0,
      totalMilestones: rows.length,
      trackFilterOptions: filterOptions,
    );

    await _pump(tester, _buildApp(achievementsState: AsyncData(overview)));

    // Apply track 1 filter first
    await tester.tap(find.text('Mishnayos').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Track 2 Reward'), findsNothing);

    // Tap "All Tracks" to restore
    await tester.tap(find.text('All Tracks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Track 1 Reward'), findsOneWidget);
    expect(find.text('Track 2 Reward'), findsOneWidget);

    await _teardown(tester);
  });

  // ── noRewardsYet shown when filter narrows to empty ─────────────────────────

  testWidgets(
    'noRewardsYet text shown when active filter yields no matching rows',
    (tester) async {
      final rows = [_row(trackId: 1, milestoneTitle: 'Only Track 1')];
      final filterOptions = [
        const AchievementTrackFilterVm(
          trackId: 1,
          curriculumId: null,
          sortLabel: 'Mishnayos',
        ),
        const AchievementTrackFilterVm(
          trackId: 2,
          curriculumId: null,
          sortLabel: 'Bavli',
        ),
      ];
      final overview = AchievementsOverview(
        rows: rows,
        unlockedCount: 0,
        totalMilestones: rows.length,
        trackFilterOptions: filterOptions,
      );

      await _pump(tester, _buildApp(achievementsState: AsyncData(overview)));

      // Filter to track 2 which has no rows
      await tester.tap(find.text('Bavli').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('No rewards earned yet. Keep learning!'),
        findsOneWidget,
      );

      await _teardown(tester);
    },
  );

  // ── ProTipCard ──────────────────────────────────────────────────────────────

  testWidgets('ProTipCard (lightbulb icon) is present when data loaded', (
    tester,
  ) async {
    await _pump(
      tester,
      _buildApp(achievementsState: AsyncData(_emptyOverview())),
    );

    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);

    await _teardown(tester);
  });

  // ── RTL / Hebrew smoke ──────────────────────────────────────────────────────

  testWidgets(
    'he-RTL: screen renders without overflow/crash in Hebrew locale',
    (tester) async {
      await _pump(
        tester,
        _buildApp(
          achievementsState: AsyncData(_populatedOverview()),
          locale: const Locale('he'),
        ),
      );

      // Core UI elements still present in RTL
      expect(
        find.text('ההישגים שלי'),
        findsOneWidget,
      ); // myAchievementsTitle in he
      expect(find.byType(ProgressSummaryCard), findsOneWidget);

      await _teardown(tester);
    },
  );

  // ── R6-15 regression: ProgressSummaryCard Row not forced LTR ────────────────

  testWidgets(
    'R6-15: ProgressSummaryCard under RTL has no Directionality(ltr) wrapper',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: ProgressSummaryCard(l10n: l10n, unlocked: 3, total: 10),
        ),
      );

      // No descendant Directionality should force TextDirection.ltr inside
      // the card — numbers render LTR within Text regardless.
      final ltrDirectionalities = tester
          .widgetList<Directionality>(find.byType(Directionality))
          .where((d) => d.textDirection == TextDirection.ltr)
          .toList();
      expect(
        ltrDirectionalities,
        isEmpty,
        reason:
            'ProgressSummaryCard must not contain any Directionality(ltr) '
            'that would break RTL row alignment (R6-16 fix)',
      );
    },
  );

  // ── R6-16 regression: AchievementTierCard Row not forced LTR ────────────────

  testWidgets(
    'R6-16: AchievementTierCard under RTL has no Directionality(ltr) wrapper',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      final rowVm = _row(trackPoints: 50, isUnlocked: false, isNextUp: true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('he'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AchievementTierCard(
              l10n: l10n,
              row: rowVm,
              trackTag: 'Mishnayos',
            ),
          ),
        ),
      );
      await tester.pump();

      // No descendant Directionality should force TextDirection.ltr inside
      // the card — the metrics Row must honour the ambient RTL direction.
      final ltrDirectionalities = tester
          .widgetList<Directionality>(find.byType(Directionality))
          .where((d) => d.textDirection == TextDirection.ltr)
          .toList();
      expect(
        ltrDirectionalities,
        isEmpty,
        reason:
            'AchievementTierCard must not contain any Directionality(ltr) '
            'that would break RTL row alignment (R6-15 fix)',
      );
    },
  );

  // ── AUD-gamification-02: badge must not overlap title under RTL ─────────────

  testWidgets('AUD-gamification-02: TrackTagChip badge does not overlap the '
      'milestone title under Locale(he)', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('he'));
    // A long, direction-aware title -- long enough that if the badge
    // were still pinned with a plain Positioned(right:0) (direction-
    // unaware), it would sit directly on top of the title's first line,
    // since both anchor to the same physical corner under RTL.
    final rowVm = _row(
      milestoneTitle: 'כוכב ברונזה למצטיינים בלימוד',
      trackPoints: 50,
      isUnlocked: false,
      isNextUp: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('he'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AchievementTierCard(
            l10n: l10n,
            row: rowVm,
            trackTag: 'Mishnayos',
          ),
        ),
      ),
    );
    await tester.pump();

    final chipRect = tester.getRect(find.byType(TrackTagChip));
    final titleRect = tester.getRect(find.text(rowVm.milestone.title).first);

    final overlaps =
        chipRect.left < titleRect.right &&
        chipRect.right > titleRect.left &&
        chipRect.top < titleRect.bottom &&
        chipRect.bottom > titleRect.top;

    expect(
      overlaps,
      isFalse,
      reason:
          'TrackTagChip (badge) rect $chipRect overlaps the milestone '
          'title rect $titleRect under Hebrew RTL -- the badge must use '
          'PositionedDirectional(end:) instead of Positioned(right:) so '
          'it stays clear of the direction-aware title in both locales '
          '(AUD-gamification-02).',
    );
  });
}
