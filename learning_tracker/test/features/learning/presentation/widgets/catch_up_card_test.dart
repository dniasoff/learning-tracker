// DNI-505 (Story 3.2) T6: the catch-up card on the Learn tab — top
// position and copy (AC-2), the chained label (AC-4), no card for nothing
// planned (AC-9), inline retry (AC-11), owner/profile scoping (AC-12),
// stacked cards (EC-3), and 48dp actions, semantics, text scaling, RTL and
// light/dark rendering.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _Tutor extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => TutoredProfileSelection(
    profileId: catchUpScope.profileId,
    ownerUid: 'parent-uid',
    grantId: 'grant',
    permissions: TutorPermissions.defaults(),
  );
}

class _Owner extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

final _card = find.byType(CatchUpCardView);
final _yesAll = find.byKey(const ValueKey('catchUpCardYesAll'));
final _adjust = find.byKey(const ValueKey('catchUpCardAdjust'));

/// Lakewood: Shabbos 2026-10-10 ends Saturday night; card through Sunday.
final _lakewood = constantHistory(lakewood);

LearnerState _plain() => fakeLearnerState(
  curricula: {'mishnayos': FakeCurriculumState(curriculumId: 'mishnayos')},
);

/// [_plain] with a counted catch_up for [catchUpShabbos] (complete card).
LearnerState _caughtUp() => fakeLearnerState(
  curricula: {'mishnayos': FakeCurriculumState(curriculumId: 'mishnayos')},
  countedLearns: [
    LearningEvent.learn(
      id: ulidE,
      curriculumId: 'mishnayos',
      ref: 'Mishnah Berakhot 2:1',
      source: LearningEvent.sourceMain,
      dateState: DateState.catchUp,
      learnedOn: catchUpShabbos,
      stage: 1,
      recordedAt: catchUpSunday,
      actor: parentActor,
    ),
  ],
);

List<Override> _common({bool tutor = false}) => [
  useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  activeTutoredProfileSelectionProvider.overrideWith(
    tutor ? _Tutor.new : _Owner.new,
  ),
];

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
  bool tutor = false,
  Size size = const Size(420, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      retry: (_, _) => null,
      locale: locale,
      theme: theme,
      overrides: [
        ..._common(tutor: tutor),
        ...overrides,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [CatchUpCardsSection(), Text('Below')],
        ),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

DailyTask _t(String ref) => plannedTask(ref);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('AC-2: a regular Shabbos card', () {
    testWidgets('sits at the top of the Learn tab, above today\'s tasks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pumpApp(
          retry: (_, _) => null,
          overrides: [
            ..._common(),
            ...catchUpOverrides(
              states: (_) => Stream.value(_plain()),
              history: _lakewood,
            ),
            dashboardActiveCurriculaStreamProvider.overrideWith(
              (ref) => Stream.value(const [CurriculumId.mishnayos]),
            ),
            dashboardStreakProvider.overrideWith(
              (ref) => Stream.value((currentStreak: 3, maxStreak: 5)),
            ),
            allDailyTasksProvider.overrideWith(
              (ref) => Future.value([_t('Mishnah Berakhot 3:1')]),
            ),
            selectedProfileProvider.overrideWith(
              (ref) => Future.value(
                LearnerProfileEntity(
                  profileId: 'p',
                  displayName: 'Yehuda',
                  mode: ProfileMode.child,
                  createdAt: DateTime.utc(2026),
                  updatedAt: DateTime.utc(2026),
                ),
              ),
            ),
            coarsePacedTrackIdsProvider.overrideWith(
              (ref) => Future.value(const <CurriculumId>{}),
            ),
            contentIndexProvider.overrideWith(
              (ref) => Future.value(ContentIndex.fromCurricula(const {})),
            ),
            erevSequencePlannerProvider.overrideWithValue(
              (ref, dates) async => [for (final _ in dates) const []],
            ),
          ],
          child: const Scaffold(body: LearningScreen()),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(_card, findsOneWidget);
      final daily = find.text('Daily Tasks');
      expect(daily, findsOneWidget);
      expect(
        tester.getTopLeft(_card).dy,
        lessThan(tester.getTopLeft(daily).dy),
      );
      await _unmount(tester);
    });

    testWidgets('calendar icon, question, caption and the two pills', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          history: _lakewood,
          planner: fixedPlanner({
            catchUpShabbos: [
              for (var i = 1; i <= 4; i++) _t('Mishnah Berakhot 2:$i'),
            ],
          }),
        ),
      );
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      final units = CurriculumLabels.leaf(CurriculumId.mishnayos).inLanguage(
        useHebrew: false,
        plural: true,
        variant: TransliterationVariant.ashkenazi,
      );
      expect(
        find.text('Shabbos · 4 $units planned — learnt them all?'),
        findsOneWidget,
      );
      expect(find.text('Available until the end of Sunday'), findsOneWidget);
      expect(find.text('Home · 4 $units'), findsOneWidget);
      expect(find.text('Yes, all of it'), findsOneWidget);
      expect(find.text('Adjust…'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('gone at 00:00 Monday learner-local, while open', (
      tester,
    ) async {
      var now = catchUpZone.at(DateTime.utc(2026, 10, 11), hour: 23);
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          history: _lakewood,
          clock: () => now,
        ),
      );
      expect(_card, findsOneWidget);
      // The windows re-check themselves at the card's expiry.
      now = catchUpZone.startOf(DateTime.utc(2026, 10, 12));
      await tester.pump(const Duration(hours: 1, milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 10));
      expect(_card, findsNothing);
      await _unmount(tester);
    });
  });

  group('AC-4: a diaspora yom tov chained into Shabbos', () {
    testWidgets('one card titled Yom Tov & Shabbos', (tester) async {
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          history: constantHistory(lakewood),
          clock: () => catchUpZone.at(DateTime.utc(2027, 4, 25), hour: 12),
          planner: fixedPlanner({
            '2027-04-22': [_t('Mishnah Berakhot 2:1')],
            '2027-04-23': [_t('Mishnah Berakhot 2:2')],
            '2027-04-24': [_t('Mishnah Berakhot 2:3')],
          }),
        ),
      );
      expect(_card, findsOneWidget);
      expect(find.textContaining('Yom Tov & Shabbos · 3 '), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('AC-9: nothing planned', () {
    testWidgets('no card and nothing in its place', (tester) async {
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          planner: fixedPlanner({}),
        ),
      );
      expect(_card, findsNothing);
      expect(
        find.descendant(
          of: find.byType(CatchUpCardsSection),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp('streak', caseSensitive: false)),
        findsNothing,
      );
      await _unmount(tester);
    });
  });

  group('AC-11: contents fail to load', () {
    testWidgets('inline error with retry; the card stays until its window '
        'ends', (tester) async {
      var fail = true;
      var now = catchUpSunday;
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => fail
              ? Stream.error(StateError('engine down'))
              : Stream.value(_plain()),
          clock: () => now,
        ),
      );
      expect(find.text("What was planned couldn't load."), findsOneWidget);
      expect(find.text('Available until the end of Monday'), findsOneWidget);
      final retry = find.byKey(const ValueKey('catchUpCardRetry'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));

      // Retry re-reads and recovers.
      fail = false;
      await tester.tap(retry);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(_card, findsOneWidget);
      await _unmount(tester);

      // Still failing at the end of its window: gone with the window.
      fail = true;
      now = catchUpZone.startOf(DateTime.utc(2026, 10, 13));
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.error(StateError('engine down')),
          clock: () => now,
        ),
      );
      expect(find.text("What was planned couldn't load."), findsNothing);
      await _unmount(tester);
    });
  });

  group('AC-12: owner devices, the profile in view', () {
    testWidgets('a tutor device shows no card', (tester) async {
      await _pumpSection(
        tester,
        tutor: true,
        overrides: catchUpOverrides(states: (_) => Stream.value(_plain())),
      );
      expect(_card, findsNothing);
      await _unmount(tester);
    });

    testWidgets('an owner sees only the in-view profile\'s cards', (
      tester,
    ) async {
      LearnerState stateOf(LearnerScope s) =>
          s.profileId == catchUpScope.profileId ? _plain() : _caughtUp();
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          scope: catchUpOtherScope,
          states: (s) => Stream.value(stateOf(s)),
        ),
      );
      expect(_card, findsNothing);
      await _unmount(tester);
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(states: (s) => Stream.value(stateOf(s))),
      );
      expect(_card, findsOneWidget);
      await _unmount(tester);
    });
  });

  group('EC-3: stacked cards', () {
    final jlm = LearnerZone.of('Asia/Jerusalem');
    final israel = constantHistory(jerusalem);
    final planner = fixedPlanner({
      '2027-04-22': [_t('Mishnah Berakhot 2:1')],
      '2027-04-24': [_t('Mishnah Berakhot 2:2')],
    });

    testWidgets('oldest first, each with its own caption, as time advances', (
      tester,
    ) async {
      var now = jlm.at(DateTime.utc(2027, 4, 23), hour: 9);
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          history: israel,
          clock: () => now,
          planner: planner,
        ),
      );
      expect(_card, findsOneWidget);
      expect(find.textContaining('Yom Tov · 1 '), findsOneWidget);
      await _unmount(tester);

      now = jlm.at(DateTime.utc(2027, 4, 25), hour: 9);
      await _pumpSection(
        tester,
        overrides: catchUpOverrides(
          states: (_) => Stream.value(_plain()),
          history: israel,
          clock: () => now,
          planner: planner,
        ),
      );
      expect(_card, findsNWidgets(2));
      final yomTov = find.textContaining('Yom Tov · 1 ');
      final shabbos = find.textContaining('Shabbos · 1 ');
      expect(
        tester.getTopLeft(yomTov).dy,
        lessThan(tester.getTopLeft(shabbos).dy),
      );
      expect(find.text('Available until the end of Sunday'), findsNWidgets(2));
      await _unmount(tester);
    });
  });

  group('accessibility, scaling, RTL and themes', () {
    List<Override> plain() =>
        catchUpOverrides(states: (_) => Stream.value(_plain()));

    testWidgets('48dp pills, named for a screen reader, the question a '
        'header', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpSection(tester, overrides: plain());
      expect(tester.getSize(_yesAll).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(_adjust).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Yes, all of it'), findsOneWidget);
      expect(find.bySemanticsLabel('Adjust…'), findsOneWidget);
      final question = find.textContaining('learnt them all?');
      expect(tester.getSemantics(question), containsSemantics(isHeader: true));
      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('the largest text scale lays out without overflow', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        overrides: plain(),
        textScale: 2,
        size: const Size(320, 2400),
      );
      expect(tester.takeException(), isNull);
      expect(_card, findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('Hebrew is right-to-left: the icon leads on the right', (
      tester,
    ) async {
      await _pumpSection(
        tester,
        overrides: plain(),
        locale: const Locale('he'),
      );
      expect(find.text('כן, הכול'), findsOneWidget);
      final icon = tester.getCenter(find.byIcon(Icons.calendar_month_rounded));
      final question = tester.getCenter(find.textContaining('למדת את כולם?'));
      expect(icon.dx, greaterThan(question.dx));
      await _unmount(tester);
    });

    testWidgets('light and dark surfaces differ (blue-soft per theme)', (
      tester,
    ) async {
      Color surface() {
        final box = tester.widget<Container>(
          find.descendant(of: _card, matching: find.byType(Container)).first,
        );
        return (box.decoration! as BoxDecoration).color!;
      }

      await _pumpSection(
        tester,
        overrides: plain(),
        theme: AppTheme.themeFor(brightness: Brightness.light),
      );
      final light = surface();
      await _unmount(tester);
      await _pumpSection(
        tester,
        overrides: plain(),
        theme: AppTheme.themeFor(brightness: Brightness.dark),
      );
      final dark = surface();
      expect(dark, isNot(light));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    testWidgets('the actions are disabled until Stories 3.3 / 3.4 plug in', (
      tester,
    ) async {
      CatchUpTaskCard? recorded;
      await _pumpSection(
        tester,
        overrides: [
          ...plain(),
          catchUpCardActionsProvider.overrideWithValue(
            CatchUpCardActions(recordAll: (_, card) => recorded = card),
          ),
        ],
      );
      expect(tester.widget<FilledButton>(_yesAll).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(_adjust).onPressed, isNull);
      await tester.tap(_yesAll);
      expect(recorded, isNotNull);
      await _unmount(tester);
    });
  });
}
