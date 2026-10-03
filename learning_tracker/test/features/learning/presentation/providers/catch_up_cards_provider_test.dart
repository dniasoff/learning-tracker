// DNI-505 (Story 3.2) T6: the catch-up cards provider composes live
// inputs (AC-8, AC-11, AC-12). AC-5's gap is covered by
// test/domain/learner_state/catch_up_card_projection_test.dart.
@Tags(['learning'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';

LearnerState _withRebbe() => fakeLearnerState(
  curricula: {
    'mishnayos': FakeCurriculumState(
      curriculumId: 'mishnayos',
      subTracks: {
        'rebbe': const SubTrackState(
          subTrackId: 'rebbe',
          holdsGround: true,
          inForecast: true,
          onHome: true,
          position: 'Mishnah_Peah_1.1',
          remainingPath: ['Mishnah_Peah_1.1', 'Mishnah_Peah_1.2'],
        ),
      },
    ),
  },
);

Future<List<CatchUpTaskCard>> _settle(ProviderContainer c) async {
  final sub = c.listen(catchUpCardsProvider.future, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

void main() {
  group('AC-8: a live learns_on_shabbos edit', () {
    test(
      'the sub-track group follows the current flag; the lock stays',
      () async {
        final tracks = LiveSource<List<SubTrack>>([catchUpSubTrack('rebbe')]);
        addTearDown(tracks.close);
        final container = ProviderContainer(
          overrides: catchUpOverrides(
            states: (_) => Stream.value(_withRebbe()),
            subTracks: (_) => tracks.stream(),
          ),
        );
        addTearDown(container.dispose);
        final sub = container.listen(catchUpCardsProvider, (_, _) {});
        addTearDown(sub.close);

        final before = await _settle(container);
        final day = before.single.groups.single.days.single;
        expect(day.subTracks.single.name, 'Rebbe');
        expect(day.subTracks.single.leaves, ['Mishnah_Peah_1.1']);

        tracks.value = [catchUpSubTrack('rebbe', learnsOnShabbos: false)];
        await pumpEventQueue();
        final after = await _settle(container);
        expect(after.single.groups.single.days.single.subTracks, isEmpty);
        expect(after.single.window.lock, before.single.window.lock);
      },
    );
  });

  group('AC-12: owner devices only, scoped to the learner in view', () {
    test('a tutored session has no windows and no cards', () async {
      final container = ProviderContainer(
        overrides: catchUpOverrides(states: (_) => Stream.value(_withRebbe())),
      );
      addTearDown(container.dispose);
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(
            TutoredProfileSelection(
              profileId: catchUpScope.profileId,
              ownerUid: 'parent-uid',
              grantId: 'grant',
              permissions: TutorPermissions.defaults(),
            ),
          );
      expect(await _settle(container), isEmpty);
      final windows = container.listen(
        catchUpCardWindowsProvider.future,
        (_, _) {},
      );
      addTearDown(windows.close);
      expect(await windows.read(), isEmpty);
    });

    test('the learner state read is the scope in view', () async {
      final seen = <String>[];
      final container = ProviderContainer(
        overrides: catchUpOverrides(
          scope: catchUpOtherScope,
          states: (scope) {
            seen.add(scope.profileId);
            return Stream.value(_withRebbe());
          },
        ),
      );
      addTearDown(container.dispose);
      expect(await _settle(container), hasLength(1));
      expect(seen, [catchUpOtherScope.profileId]);
    });
  });

  group('AC-11: a contents failure keeps the window', () {
    test('the cards fail; the pending window stays', () async {
      final container = ProviderContainer(
        overrides: catchUpOverrides(
          states: (_) => Stream.error(StateError('engine down')),
        ),
      );
      addTearDown(container.dispose);
      await expectLater(_settle(container), throwsA(isA<StateError>()));
      final windows = container.listen(
        catchUpCardWindowsProvider.future,
        (_, _) {},
      );
      addTearDown(windows.close);
      expect(await windows.read(), hasLength(1));
    });
  });

  group('timing', () {
    test('no windows inside the lock or after the card expired', () async {
      for (final at in [
        catchUpZone.at(DateTime.utc(2026, 10, 10), hour: 12),
        catchUpZone.startOf(DateTime.utc(2026, 10, 13)),
      ]) {
        final container = ProviderContainer(
          overrides: catchUpOverrides(
            states: (_) => Stream.value(_withRebbe()),
            clock: () => at,
          ),
        );
        final windows = container.listen(
          catchUpCardWindowsProvider.future,
          (_, _) {},
        );
        expect(await windows.read(), isEmpty, reason: '$at');
        windows.close();
        container.dispose();
      }
    });
  });
}
