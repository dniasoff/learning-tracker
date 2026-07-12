import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/curriculum_summary_card.dart';
// points_summary_widget.dart was deleted (dead-code purge, AUD-dashboard-04).
// todays_tasks_widget.dart was deleted in W1.21 (dead-code purge).
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Load real fonts so text renders in golden screenshots instead of Ahem boxes.
Future<void> loadFonts() async {
  const fontDir =
      '/home/daniel/fvm/versions/stable/bin/cache/artifacts/material_fonts';

  // Load Roboto variants (Flutter's default Material font)
  final robotoVariants = {
    'Roboto': [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Light.ttf',
      'Roboto-Thin.ttf',
      'Roboto-Black.ttf',
      'Roboto-Italic.ttf',
    ],
  };

  for (final entry in robotoVariants.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final path = '$fontDir/$file';
      if (File(path).existsSync()) {
        final bytes = File(path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await loader.load();
  }

  // Load MaterialIcons
  // ignore: prefer_const_declarations
  final iconsPath = '$fontDir/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final loader = FontLoader('MaterialIcons');
    final bytes = File(iconsPath).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// Wraps content in a phone-sized Material app with the real theme.
Widget phoneApp({required Widget child}) {
  return ProviderScope(
    child: MediaQuery(
      data: const MediaQueryData(
        size: Size(1080 / 2.625, 1920 / 2.625), // ~411x731 logical pixels
        devicePixelRatio: 2.625,
        padding: EdgeInsets.only(top: 24, bottom: 0),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme(),
        home: child,
      ),
    ),
  );
}

/// Golden file path helper - files go into test/golden/goldens/
String _golden(String name) => 'goldens/$name';

void main() {
  setUpAll(() async {
    await loadFonts();
  });

  setUp(() {
    // CurriculumLabel now watches `useHebrewTermsProvider`, which reads
    // SharedPreferences; without an in-memory mock the dashboard widget
    // throws MissingPluginException before the golden snapshot is taken.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Play Store Screenshots', () {
    testWidgets('Screenshot 1: Dashboard (child mode)', (tester) async {
      // Set phone-sized surface
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();

      final summaries = [
        CurriculumSummary(
          curriculumId: CurriculumId.mishnayos,
          completionPercentage: 0.42,
          paceStatus: const PaceStatus(
            status: PaceStatusType.ahead,
            daysDelta: 3,
            delta: DateScheduleDelta(DateDelta(3)),
            rollingAverage: 5.2,
          ),
          nextDueItem: 'Berachot 3:5',
          todayTaskCount: 2,
          lastCompletionAt: now,
        ),
        CurriculumSummary(
          curriculumId: CurriculumId.bavli,
          completionPercentage: 0.18,
          paceStatus: const PaceStatus(
            status: PaceStatusType.onPace,
            daysDelta: 0,
            delta: DateScheduleDelta(DateDelta(0)),
            rollingAverage: 1.1,
          ),
          nextDueItem: 'Brachot 24a',
          todayTaskCount: 1,
          lastCompletionAt: now.subtract(const Duration(hours: 2)),
        ),
        CurriculumSummary(
          curriculumId: CurriculumId.chumash,
          completionPercentage: 0.65,
          paceStatus: const PaceStatus(
            status: PaceStatusType.ahead,
            daysDelta: 7,
            delta: DateScheduleDelta(DateDelta(7)),
            rollingAverage: 8.0,
          ),
          nextDueItem: 'Bereishit 12:5',
          todayTaskCount: 1,
          lastCompletionAt: now.subtract(const Duration(hours: 5)),
        ),
        CurriculumSummary(
          curriculumId: CurriculumId.mishnaBerurah,
          completionPercentage: 0.33,
          paceStatus: const PaceStatus(
            status: PaceStatusType.behind,
            daysDelta: -2,
            delta: DateScheduleDelta(DateDelta(-2)),
            rollingAverage: 2.3,
          ),
          nextDueItem: 'Siman 91:2',
          todayTaskCount: 1,
          lastCompletionAt: now.subtract(const Duration(days: 1)),
        ),
        CurriculumSummary(
          curriculumId: CurriculumId.nach,
          completionPercentage: 0.28,
          paceStatus: null,
          nextDueItem: 'Yehoshua 5:3',
          todayTaskCount: 0,
          lastCompletionAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      await tester.pumpWidget(
        phoneApp(
          child: Scaffold(
            appBar: AppBar(
              title: const AppBarTitle(text: "Dani's Dashboard"),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const ProfileAvatar(avatarIndex: 3, radius: 16),
                  tooltip: 'Switch profile',
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const StreakWidget(
                    currentStreak: 14,
                    maxStreak: 42,
                    userMode: ProfileMode.child,
                  ),
                  // PointsSummaryWidget removed (dead code, AUD-dashboard-04).
                  // TodaysTasksWidget removed (widget deleted W1.21)
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continue learning Mishnayos'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.auto_stories,
                        color: Colors.deepPurple,
                      ),
                      title: const Text('My Learning Journey'),
                      subtitle: const Text('See your lifetime achievements'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...summaries.map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CurriculumSummaryCard(
                        summary: summary,
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Let animations run a bit then capture
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_golden('phone_1_dashboard.png')),
      );
    });

    testWidgets('Screenshot 2: Learning - Add Track', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final masechtos = [
        ('Berachot', '9 chapters • 57 mishnayos', 1.0, true),
        ('Peah', '8 chapters • 69 mishnayos', 0.75, false),
        ('Demai', '7 chapters • 53 mishnayos', 0.45, false),
        ('Kilayim', '9 chapters • 75 mishnayos', 0.12, false),
        ('Sheviit', '10 chapters • 81 mishnayos', 0.0, false),
        ('Terumot', '11 chapters • 100 mishnayos', 0.0, false),
        ('Maasrot', '5 chapters • 41 mishnayos', 0.0, false),
        ('Maaser Sheni', '5 chapters • 55 mishnayos', 0.0, false),
      ];

      await tester.pumpWidget(
        phoneApp(
          child: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: const AppBarTitle(text: 'Seder Zeraim'),
            ),
            body: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: masechtos.length,
              itemBuilder: (context, index) {
                final (name, detail, progress, completed) = masechtos[index];
                final theme = Theme.of(context);
                const color = Color(0xFF4A90E2);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {},
                    child: Row(
                      children: [
                        Container(width: 6, height: 80, color: color),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    if (completed)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF6B9080),
                                        size: 24,
                                      )
                                    else if (progress > 0)
                                      Text(
                                        '${(progress * 100).round()}%',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  detail,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (progress > 0 && !completed) ...[
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    valueColor: const AlwaysStoppedAnimation(
                                      color,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!completed)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_golden('phone_2_learning.png')),
      );
    });

    testWidgets('Screenshot 3: Progress Overview', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        phoneApp(
          child: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Progress')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stats row
                Row(
                  children: [
                    _StatCard(
                      'Total Learned',
                      '2,847',
                      AppTheme.lightTheme().colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'This Week',
                      '142',
                      AppTheme.lightTheme().colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Avg/Day',
                      '23',
                      AppTheme.lightTheme().colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekly activity chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(height: 200, child: _WeeklyChart()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Curriculum breakdown
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curriculum Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        _CurriculumProgress(
                          'Mishnayos',
                          0.42,
                          AppTheme.curriculumMishna,
                        ),
                        _CurriculumProgress(
                          'Talmud Bavli',
                          0.18,
                          AppTheme.curriculumBavli,
                        ),
                        _CurriculumProgress(
                          'Chumash',
                          0.65,
                          AppTheme.curriculumChumash,
                        ),
                        _CurriculumProgress(
                          'Mishna Berurah',
                          0.33,
                          AppTheme.curriculumMishnaBerurah,
                        ),
                        _CurriculumProgress(
                          'Nach',
                          0.28,
                          AppTheme.curriculumNach,
                        ),
                        _CurriculumProgress(
                          'Mussar',
                          0.12,
                          AppTheme.curriculumMussar,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Milestones
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Milestones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _MilestoneItem(
                          'Completed Masechet Berachot',
                          'Mishnayos • 2 days ago',
                          Icons.emoji_events,
                          Colors.amber,
                        ),
                        _MilestoneItem(
                          '1000 Units Learned',
                          'Lifetime achievement',
                          Icons.star,
                          Color(0xFF6B9080),
                        ),
                        _MilestoneItem(
                          '14-Day Streak',
                          'Personal best!',
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_golden('phone_3_progress.png')),
      );
    });

    testWidgets('Screenshot 4: Scheduler', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        phoneApp(
          child: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Today\'s Schedule')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Goal card
                Card(
                  color: AppTheme.lightTheme().colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flag,
                              color: AppTheme.lightTheme().colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Complete Seder Zeraim',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '47',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.lightTheme()
                                        .colorScheme
                                        .secondary,
                                  ),
                                ),
                                const Text(
                                  'days left',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: 0.42,
                          backgroundColor: AppTheme.lightTheme()
                              .colorScheme
                              .surfaceContainerHighest,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '42% complete',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Today\'s Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                const _TaskItem(
                  'Mishnayos',
                  'Berachot 3:5–3:8',
                  '~15 min',
                  AppTheme.curriculumMishna,
                  done: true,
                ),
                const _TaskItem(
                  'Talmud Bavli',
                  'Brachot 24a',
                  '~30 min',
                  AppTheme.curriculumBavli,
                  done: true,
                ),
                const _TaskItem(
                  'Chumash',
                  'Bereishit 12:1–12:10',
                  '~10 min',
                  AppTheme.curriculumChumash,
                  done: false,
                ),
                const _TaskItem(
                  'Mishna Berurah',
                  'Siman 91:1–91:3',
                  '~20 min',
                  AppTheme.curriculumMishnaBerurah,
                  done: false,
                ),
                const _TaskItem(
                  'Nach',
                  'Yehoshua 5:1–5:12',
                  '~10 min',
                  AppTheme.curriculumNach,
                  done: false,
                ),

                const SizedBox(height: 16),

                // Summary
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow('Daily target', '~85 min'),
                        Divider(),
                        _SummaryRow('Completed', '2 of 5'),
                        Divider(),
                        _SummaryRow('Pace', 'On track ✓'),
                        Divider(),
                        _SummaryRow('Tracks', 'Personal, School'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_golden('phone_4_scheduler.png')),
      );
    });

    testWidgets('Screenshot 5: Achievements / Gamification', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        phoneApp(
          child: Scaffold(
            appBar: AppBar(title: const AppBarTitle(text: 'Achievements')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Streak showcase
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '14',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Day Streak!',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Week dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final (day, done) in [
                              ('S', true),
                              ('M', true),
                              ('T', true),
                              ('W', true),
                              ('T', true),
                              ('F', true),
                              ('S', false),
                            ])
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: done
                                        ? const Color(0xFFF4A261)
                                        : Colors.grey[300],
                                    child: done
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            day,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    day,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Points
                Card(
                  color: const Color(0xFF6B9080).withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFF6B9080),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '1,247 Points',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B9080),
                            ),
                          ),
                        ),
                        Text(
                          '+23 today',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Achievements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                const _AchievementTile(
                  'First Steps',
                  'Complete your first lesson',
                  Icons.spa,
                  Colors.green,
                  true,
                ),
                const _AchievementTile(
                  'Week Warrior',
                  '7-day streak',
                  Icons.shield,
                  Colors.blue,
                  true,
                ),
                const _AchievementTile(
                  'Seder Master',
                  'Complete a full Seder',
                  Icons.menu_book,
                  Colors.purple,
                  true,
                ),
                const _AchievementTile(
                  'Torah Scholar',
                  'Learn 1000 units',
                  Icons.school,
                  Color(0xFFF4A261),
                  true,
                ),
                const _AchievementTile(
                  'Consistency King',
                  '30-day streak',
                  Icons.diamond,
                  Colors.amber,
                  false,
                ),
                const _AchievementTile(
                  'Shas Journey',
                  'Start Talmud Bavli',
                  Icons.account_balance,
                  Colors.indigo,
                  true,
                ),
                const _AchievementTile(
                  'Full Review',
                  'Complete all chazara stages',
                  Icons.replay,
                  Colors.teal,
                  false,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_golden('phone_5_gamification.png')),
      );
    });
  });
}

// ─── Helper Widgets ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shab'];
    final values = [18, 25, 22, 30, 28, 15, 35];
    const maxVal = 35;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${values[i]}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: (values[i] / maxVal) * 150,
                  decoration: BoxDecoration(
                    color: days[i] == 'Shab'
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(days[i], style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CurriculumProgress extends StatelessWidget {
  final String name;
  final double progress;
  final Color color;

  const _CurriculumProgress(this.name, this.progress, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(name, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MilestoneItem(this.title, this.subtitle, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String curriculum;
  final String detail;
  final String duration;
  final Color color;
  final bool done;

  const _TaskItem(
    this.curriculum,
    this.detail,
    this.duration,
    this.color, {
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: done
            ? Icon(Icons.check_circle, color: theme.colorScheme.tertiary)
            : CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
        title: Text(
          curriculum,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          detail,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.grey : null,
          ),
        ),
        trailing: Text(
          duration,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _AchievementTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.unlocked,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: unlocked
              ? color.withValues(alpha: 0.2)
              : Colors.grey[200],
          child: Icon(
            unlocked ? icon : Icons.lock,
            color: unlocked ? color : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: unlocked ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: unlocked ? null : Colors.grey),
        ),
      ),
    );
  }
}
