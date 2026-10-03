// DNI-505 (Story 3.2) T5, AC-10: a counted catch_up event written on one
// device hides the matching lock card on every device of the profile once
// it is in LearnerState, and voiding it (undo) while the window is open
// brings the card back (A-5).
//
// Two "devices" (provider containers) watch one shared event log; each
// derives its LearnerState from it with the REAL engine, so counted and
// voided events follow the engine's own rules.
@Tags(['learning'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';

import '../helpers/learner_state/catch_up_card_harness.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

LearningEvent _catchUp(int id, {String learnedOn = catchUpShabbos}) =>
    LearningEvent.learn(
      id: engineUlid(id),
      curriculumId: engineCurriculum,
      ref: 'Mishnah Berakhot 1:1',
      source: LearningEvent.sourceMain,
      dateState: DateState.catchUp,
      learnedOn: learnedOn,
      stage: 1,
      recordedAt: catchUpSunday.subtract(const Duration(hours: 1)),
      actor: parentActor,
    );

LearningEvent _void(int id, int target) => LearningEvent.voidOf(
  id: engineUlid(id),
  targetId: engineUlid(target),
  recordedAt: catchUpSunday.subtract(const Duration(minutes: 30)),
  actor: parentActor,
);

LearnerState _derive(List<LearningEvent> events) =>
    const LearnerStateEngine().run(
      engineInputs(
        events: events,
        settingsHistory: catchUpHistory,
        nowUtc: catchUpSunday,
      ),
    );

void main() {
  late LiveSource<List<LearningEvent>> log;
  late List<ProviderContainer> devices;
  late List<ProviderSubscription<AsyncValue<List<CatchUpTaskCard>>>> subs;

  setUp(() {
    log = LiveSource<List<LearningEvent>>(const []);
    devices = [
      for (var i = 0; i < 2; i++)
        ProviderContainer(
          overrides: catchUpOverrides(states: (_) => log.stream().map(_derive)),
        ),
    ];
    subs = [for (final d in devices) d.listen(catchUpCardsProvider, (_, _) {})];
  });

  tearDown(() async {
    for (final s in subs) {
      s.close();
    }
    for (final d in devices) {
      d.dispose();
    }
    await log.close();
  });

  Future<List<int>> cardsPerDevice() async {
    await pumpEventQueue();
    return [
      for (final d in devices)
        (await d.read(catchUpCardsProvider.future)).length,
    ];
  }

  test('a counted catch_up hides the card on both devices; voiding it '
      'brings the card back while the window is open', () async {
    expect(await cardsPerDevice(), [1, 1]);

    // Device A records the catch-up; it syncs into the shared log.
    log.value = [_catchUp(1)];
    expect(await cardsPerDevice(), [0, 0]);

    // Undo on device B voids every catch_up event of the lock.
    log.value = [_catchUp(1), _void(2, 1)];
    expect(await cardsPerDevice(), [1, 1]);
  });

  test('a catch_up for another day leaves the card', () async {
    log.value = [_catchUp(1, learnedOn: '2026-10-03')];
    expect(await cardsPerDevice(), [1, 1]);
  });
}
