// Mirror test for
// `lib/features/progress/presentation/widgets/siyum_celebration.dart`
// (DNI-474 AC-4: per-device key, fires once, void clears, re-completion
// fires again, reduce-motion, local preference failures).
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_celebration_policy.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_celebration.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _peahDone = [
  progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
  progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
];

String _key(DateTime at) => ProfileScopedPreferenceKeys.siyumShown(
  profileUlid,
  engineCurriculum,
  'Mishnah Peah',
  at,
);

/// The harness: a controllable learner state and a recording presenter.
final class _Harness {
  // Closed at teardown.
  // ignore: close_sinks
  final states = StreamController<LearnerState>.broadcast();
  final shown = <(List<SiyumToCelebrate>, bool)>[];

  Widget app({bool disableAnimations = false}) => pumpApp(
    overrides: [
      ...learnerStateOverrides(scope: c0Scope()),
      learnerStateProvider.overrideWith((ref, _) => states.stream),
      corporaProvider.overrideWith(
        (ref) async => <String, Corpus>{engineCurriculum: progressCorpus()},
      ),
      siyumCelebrationPresenterProvider.overrideWithValue((
        context,
        siyumim, {
        required reduceMotion,
      }) async {
        shown.add((siyumim, reduceMotion));
      }),
    ],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const SiyumCelebrationListener(child: SizedBox()),
    ),
  );

  /// Pumps the listener and lets the scope resolve, so the learner-state
  /// stream is subscribed before the first emission.
  Future<void> start(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(app(disableAnimations: disableAnimations));
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, List<LearningEvent> events) async {
    states.add(progressState(events));
    await tester.pumpAndSettle();
  }
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());
  tearDown(() => h.states.close());

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  testWidgets('the first evaluation on a device seeds existing siyumim '
      'silently', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await h.start(tester);
    await h.emit(tester, _peahDone);
    expect(h.shown, isEmpty);
    expect((await prefs()).getBool(_key(engineAt(2))), isTrue);
    expect(
      (await prefs()).getBool(
        ProfileScopedPreferenceKeys.siyumShownSeeded(profileUlid),
      ),
      isTrue,
    );
  });

  testWidgets('a new completion fires once; rebuilds and the same state '
      'again do not replay it', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileScopedPreferenceKeys.siyumShownSeeded(profileUlid): true,
    });
    await h.start(tester);
    await h.emit(tester, [progressLearn(1, 'Mishnah Peah 1:1', minutes: 1)]);
    expect(h.shown, isEmpty);

    await h.emit(tester, _peahDone);
    expect(h.shown, hasLength(1));
    expect(
      h.shown.single.$1.single.unit,
      const NodeEntry(level: 'masechta', ref: 'Mishnah Peah'),
    );
    expect(h.shown.single.$2, isFalse, reason: 'motion allowed');

    await h.emit(tester, _peahDone);
    await h.emit(tester, [
      ..._peahDone,
      progressLearn(3, 'Mishnah Peah 1:1', minutes: 3, stage: 2),
    ]);
    expect(h.shown, hasLength(1), reason: 'chazara never re-fires');
  });

  testWidgets('a void clears the key; the re-completion fires with its new '
      'key', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileScopedPreferenceKeys.siyumShownSeeded(profileUlid): true,
      _key(engineAt(2)): true,
    });
    await h.start(tester);
    await h.emit(tester, [..._peahDone, engineVoid(3, 2, minutes: 3)]);
    expect(h.shown, isEmpty);
    expect((await prefs()).getBool(_key(engineAt(2))), isNull);

    await h.emit(tester, [
      ..._peahDone,
      engineVoid(3, 2, minutes: 3),
      progressLearn(4, 'Mishnah Peah 1:2', minutes: 8),
    ]);
    expect(h.shown, hasLength(1));
    expect(h.shown.single.$1.single.completedAt, engineAt(8));
    expect((await prefs()).getBool(_key(engineAt(8))), isTrue);
  });

  testWidgets('reduce-motion reaches the presenter', (tester) async {
    SharedPreferences.setMockInitialValues({
      ProfileScopedPreferenceKeys.siyumShownSeeded(profileUlid): true,
    });
    await h.start(tester, disableAnimations: true);
    await h.emit(tester, _peahDone);
    expect(h.shown.single.$2, isTrue);
  });

  testWidgets('the dialog names the unit and drops the confetti under '
      'reduce-motion', (tester) async {
    final siyum = SiyumToCelebrate(
      curriculumId: engineCurriculum,
      unit: const NodeEntry(level: 'masechta', ref: 'Mishnah Peah'),
      completedAt: engineAt(2),
    );
    await tester.pumpWidget(
      pumpApp(
        child: Builder(
          builder: (context) => SiyumCelebrationDialog(
            siyumim: [siyum, siyum],
            reduceMotion: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Siyum!'), findsOneWidget);
    expect(find.textContaining('Mishnah Peah'), findsOneWidget);
    expect(find.text('and 1 more'), findsOneWidget);
    expect(find.byType(ConfettiWidget), findsNothing);

    await tester.pumpWidget(
      pumpApp(
        child: SiyumCelebrationDialog(siyumim: [siyum], reduceMotion: false),
      ),
    );
    await tester.pump();
    expect(find.byType(ConfettiWidget), findsOneWidget);
  });
}
