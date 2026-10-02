// Story 2.11 (DNI-502) AC-6: the child-mode sweep of the Epic 2 surfaces.
//
// With no parent PIN, no Dashboard or Learn surface shows an on-track
// card, a status ("On track", "Behind pace", "Too early to tell", "off
// track"), a projection or deadline, a shortfall card or a shortfall
// count, in English or Hebrew, in visible text or in semantics (NFR-9,
// UX-DR-48, UX-DR-97). The child still sees "Today {done} of {target}
// done", warm encouragement and the streak of the curriculum in view
// (UX-DR-67).
//
// Scope note: the sub-track detail surface (Story 2.6, DNI-497) and the
// Dashboard sub-track summary cards (Story 2.9, DNI-500) are not on
// integ/sub-tracks yet. Each of those stories adds its surface to
// [_surfaces] below when it lands (the rulings order this sweep last in
// Epic 2).
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/dashboard/epic2_surfaces.dart';
import '../../helpers/dashboard/forecast_fixtures.dart';

/// Every parent-only forecast string, in both locales, reduced to its
/// fixed text (placeholders removed), plus the PRD's "off track".
List<String> _bannedFragments() {
  final banned = <String>{'off track', 'Off track', 'shortfall'};
  for (final locale in const [Locale('en'), Locale('he')]) {
    final l10n = lookupAppLocalizations(locale);
    banned.addAll([
      l10n.onTrackOnTrack,
      l10n.onTrackBehindPace,
      l10n.onTrackTooEarly,
      l10n.onTrackFinishUnknown,
    ]);
    // The fixed head of each templated parent line.
    for (final templated in [
      l10n.onTrackProjectedFinish('\u0000'),
      l10n.onTrackDailyTarget('\u0000', '\u0000'),
      l10n.shortfallCardMessage(
        '\u0000',
        '\u0000',
        '\u0000',
        '\u0000',
        '\u0000',
      ),
    ]) {
      banned.addAll(
        templated
            .split('\u0000')
            .map((s) => s.trim())
            .where((s) => s.length >= 4),
      );
    }
  }
  return banned.toList();
}

/// The parent-facing state the child must never see: every status, a
/// projection against a deadline and two short sub-tracks.
LearnerState _state(ProjectionStatus status) => forecastState([
  forecastCurriculumState(
    projection: Projection(
      status: status,
      velocityPerDay: 1,
      projectedFinish: '2030-01-02',
      deadline: '2029-09-10',
      newlyLearntToday: 3,
    ),
    dailyTarget: 4,
    streak: const CurriculumStreak(current: 6, best: 9),
    subTracks: {
      schoolSubTrackId: shortfallSubTrack(
        id: schoolSubTrackId,
        name: 'School',
        shortfall: 40,
        lastNode: const NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot 3'),
        windowEnd: '2027-07-31',
      ),
      rebbeSubTrackId: shortfallSubTrack(
        id: rebbeSubTrackId,
        name: 'Rebbe',
        shortfall: 12,
        lastNode: const NodeEntry(level: 'masechta', ref: 'Mishnah Beitzah'),
      ),
    },
  ),
]);

typedef _Surface =
    Widget Function(StackRouter router, bool parent, LearnerState state);

final Map<String, _Surface> _surfaces = {
  'Dashboard': (router, parent, state) =>
      dashboardSurface(router: router, parent: parent, state: state),
  'Learn': (router, parent, state) =>
      learnSurface(router: router, parent: parent, state: state),
};

/// Every visible string and every semantics label on screen.
List<String> _everything(WidgetTester tester) {
  final texts = <String>[
    for (final w in tester.widgetList<RichText>(find.byType(RichText)))
      w.text.toPlainText(),
  ];
  for (final node in find.semantics.byPredicate((_) => true).evaluate()) {
    final data = node.getSemanticsData();
    texts.addAll([data.label, data.value, data.hint, data.tooltip]);
  }
  return texts.where((t) => t.isNotEmpty).toList();
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  late StackRouter router;
  setUp(() {
    final mock = Epic2MockRouter();
    when(() => mock.isRouteActive(any())).thenReturn(false);
    router = mock;
  });

  final banned = _bannedFragments();

  for (final MapEntry(key: name, value: surface) in _surfaces.entries) {
    for (final status in [
      ProjectionStatus.onTrack,
      ProjectionStatus.behindPace,
      ProjectionStatus.tooEarly,
    ]) {
      testWidgets('$name in child mode (${status.name}): no status, '
          'projection or shortfall anywhere', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(surface(router, false, _state(status)));
        await tester.pumpAndSettle();

        expect(find.byType(OnTrackCard), findsNothing);
        expect(find.byType(ShortfallWarningCard), findsNothing);
        final everything = _everything(tester);
        for (final fragment in banned) {
          expect(
            everything.where((t) => t.contains(fragment)),
            isEmpty,
            reason: '"$fragment" leaked on the child $name',
          );
        }
        // No shortfall count either.
        for (final count in const ['About 40', 'About 12', 'כ־40', 'כ־12']) {
          expect(everything.where((t) => t.contains(count)), isEmpty);
        }

        // Encouragement, today against the target and the streak remain.
        expect(find.text('Today 3 of 4 done'), findsOneWidget);
        expect(
          find.text("Great pace! Only one left to finish today's goal."),
          findsOneWidget,
        );
        expect(find.text('6-day streak'), findsOneWidget);
        semantics.dispose();
      });
    }
  }

  testWidgets('control: the parent Dashboard does show them', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      dashboardSurface(
        router: router,
        parent: true,
        state: _state(ProjectionStatus.behindPace),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnTrackCard), findsOneWidget);
    expect(find.byType(ShortfallWarningCard), findsNWidgets(2));
    // The sweep's detector finds the parent copy in text and semantics.
    final everything = _everything(tester);
    expect(everything.where((t) => t.contains('Behind pace')), isNotEmpty);
    expect(
      everything.where((t) => t.contains('will return to home learning')),
      isNotEmpty,
    );
    // The parent sees the target on the card, not the child's section.
    expect(find.text('Today 3 of 4 done'), findsNothing);
    semantics.dispose();
  });
}
