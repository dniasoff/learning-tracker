/// Widget rig for the Story 3.4 (DNI-507) *Adjust…* panel tests: one
/// pending Shabbos card (DNI-505 harness clock and history) whose main
/// track plans Beitzah 2:7–2:10 and whose Rebbe sub-track (learns on
/// Shabbos, ten a day) plans Beitzah 3:1–3:10, over a fake learner state
/// whose track orders continue past the plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../learner_state_fixtures.dart';
import '../pump_app.dart';
import 'catch_up_card_harness.dart';
import 'fake_learner_state.dart';

/// The Rebbe sub-track's id.
const rigRebbe = ulidB;

/// Beitzah [perek]:[mishna] as a ContentIndex leaf.
LeafRef rigLeaf(int perek, int mishna) => 'Mishnah Beitzah $perek:$mishna';

/// Beitzah [perek]:[from] through [perek]:[to].
List<LeafRef> rigRun(int perek, int from, int to) => [
  for (var m = from; m <= to; m++) rigLeaf(perek, m),
];

/// The main track's planned Shabbos leaves.
final rigMainPlan = rigRun(2, 7, 10);

/// The Rebbe sub-track: ten a day, learns on Shabbos.
SubTrack rigRebbeTrack({String name = 'Rebbe'}) => SubTrack(
  id: rigRebbe,
  curriculumId: 'mishnayos',
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 70,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'chapter', ref: 'Mishnah Beitzah 3')],
  lastChangeId: ulidC,
);

/// The learner state: the Rebbe path [rebbePath] (3:1–3:12 by default)
/// and the main track's schedulable leaves [schedulable] (2:7–2:12).
LearnerState rigState({List<LeafRef>? rebbePath, List<LeafRef>? schedulable}) {
  final path = rebbePath ?? rigRun(3, 1, 12);
  final main = schedulable ?? rigRun(2, 7, 12);
  return fakeLearnerState(
    curricula: {
      'mishnayos': FakeCurriculumState(
        curriculumId: 'mishnayos',
        schedulableRefs: main,
        mainTrackPosition: main.isEmpty ? null : main.first,
        subTracks: {
          rigRebbe: SubTrackState(
            subTrackId: rigRebbe,
            holdsGround: true,
            inForecast: false,
            onHome: true,
            position: path.isEmpty ? null : path.first,
            groundExhausted: path.isEmpty,
            remainingPath: path,
          ),
        },
      ),
    },
  );
}

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _Owner extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// One device viewing the rig's card.
final class AdjustRig {
  /// Creates the rig over [state] (the [rigState] default).
  AdjustRig({LearnerState? state}) : state = LiveSource(state ?? rigState());

  /// The live learner state.
  final LiveSource<LearnerState> state;

  /// Every adjusted action the card asked to record.
  final List<CatchUpAction> recorded = [];

  /// When true, every Up to… slice fails to load (AC-7).
  bool failSlices = false;

  /// The overrides; [actions] replaces the recording card actions.
  List<Override> overrides({
    CatchUpCardActions? actions,
    bool hebrewTerms = false,
    bool realLabels = false,
  }) => [
    useHebrewTermsProvider.overrideWith(
      hebrewTerms ? _HebrewTerms.new : _EnglishTerms.new,
    ),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
    activeTutoredProfileSelectionProvider.overrideWith(_Owner.new),
    ...catchUpOverrides(
      states: (_) => state.stream(),
      subTracks: (_) => Stream.value([rigRebbeTrack()]),
      planner: fixedPlanner({
        catchUpShabbos: [for (final r in rigMainPlan) plannedTask(r)],
      }),
    ),
    if (!realLabels) ...[
      upToLeafLabelProvider.overrideWith(
        (ref, leaf) => leaf.replaceFirst('Mishnah ', ''),
      ),
      upToUnitLabelsProvider.overrideWith(
        (ref, _) => (one: 'mishna', many: 'mishnayos'),
      ),
    ],
    upToSliceProvider.overrideWith((ref, request) {
      if (failSlices) {
        return AsyncError(StateError('slice failed'), StackTrace.empty);
      }
      final curriculum = ref
          .watch(learnerStateProvider(catchUpScope))
          .asData
          ?.value
          .curricula[request.curriculumId];
      if (curriculum == null) return const AsyncLoading();
      return switch (request) {
        SubTrackUpToRequest(:final subTrackId) => AsyncData(
          UpToSlice(
            curriculumId: request.curriculumId,
            source: subTrackId,
            rows: [
              for (final r in curriculum.subTracks[subTrackId]!.remainingPath)
                UpToRow(r),
            ],
          ),
        ),
        MainTrackUpToRequest() => AsyncData(
          UpToSlice(
            curriculumId: request.curriculumId,
            source: request.source,
            rows: [for (final r in curriculum.schedulableRefs) UpToRow(r)],
          ),
        ),
      };
    }),
    catchUpCardActionsProvider.overrideWithValue(
      actions ??
          CatchUpCardActions(
            recordAdjusted: (_, _, action) => recorded.add(action),
          ),
    ),
  ];
}

/// Pumps the catch-up section on a [size] surface (phone by default).
Future<void> pumpAdjustCard(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = const Size(420, 2400),
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      retry: (_, _) => null,
      locale: locale,
      theme: theme,
      overrides: overrides,
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
  await settleAdjust(tester);
}

/// Lets the providers and the frame settle without waiting on timers.
Future<void> settleAdjust(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Unmounts the tree so the card's timers stop.
Future<void> unmountAdjust(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// The card's *Adjust…* pill.
final adjustButton = find.byKey(const ValueKey('catchUpCardAdjust'));

/// The open panel.
final adjustPanel = find.byKey(const ValueKey('catchUpAdjustPanel'));

/// The panel's *Record {n}* pill.
final adjustRecord = find.byKey(const ValueKey('catchUpAdjustRecord'));

/// The panel's Cancel (collapse) action.
final adjustCancel = find.byKey(const ValueKey('catchUpAdjustCancel'));

/// The row of [leaf] in [source]'s group on Shabbos.
Finder adjustRow(String source, LeafRef leaf) =>
    find.byKey(ValueKey('catchUpAdjustRow-$catchUpShabbos-$source-$leaf'));

/// The *Up to…* action of [source]'s group on Shabbos.
Finder adjustUpTo(String source) =>
    find.byKey(ValueKey('catchUpAdjustUpTo-$catchUpShabbos-$source'));

/// Opens the panel of the only card.
Future<void> openAdjust(WidgetTester tester) async {
  await tester.ensureVisible(adjustButton);
  await tester.tap(adjustButton);
  await settleAdjust(tester);
}
