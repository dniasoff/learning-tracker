// Mirror test for
// `lib/features/sub_tracks/presentation/providers/ground_picker_provider.dart`
// (Story 2.7 / DNI-498 AC-3, AC-6, AC-7, AC-8): the access decision fails
// closed, the inputs keep the three predicates distinct, a stored ground
// change recomputes the inputs, and the draft controller resets only the
// picks.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_provider.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

SubTrack _school([List<NodeEntry> ground = const []]) => fixtureTrack(
  schoolId,
  'School',
  curriculumId: engineCurriculum,
  ground: ground,
);

void main() {
  late GroundPickerWorld world;
  late ProviderContainer container;

  ProviderContainer start(GroundPickerWorld w) {
    world = w;
    container = ProviderContainer(overrides: w.overrides);
    addTearDown(container.dispose);
    addTearDown(w.dispose);
    // Keep the auto-dispose providers alive for the test.
    container.listen(groundPickerAccessProvider(schoolId), (_, _) {});
    return container;
  }

  Future<GroundPickerAccess> access() =>
      container.read(groundPickerAccessProvider(schoolId).future);

  Future<GroundPickerInputs> ready() async {
    final a = await access();
    expect(a, isA<GroundPickerReady>());
    return (a as GroundPickerReady).inputs;
  }

  group('access fails closed (AC-7, AC-8)', () {
    test('a child or tutored session is notParent', () async {
      start(
        GroundPickerWorld(
          corpus: mishnayosCorpus(),
          parent: false,
          tracks: [_school()],
        ),
      );
      expect(
        (await access() as GroundPickerUnavailable).reason,
        GroundPickerBlock.notParent,
      );
    });

    test('a calendar-program curriculum is blocked', () async {
      start(
        GroundPickerWorld(
          corpus: mishnayosCorpus(),
          calendarProgram: true,
          tracks: [_school()],
        ),
      );
      expect(
        (await access() as GroundPickerUnavailable).reason,
        GroundPickerBlock.calendarProgram,
      );
    });

    test('an unknown or ended sub-track is blocked', () async {
      start(GroundPickerWorld(corpus: mishnayosCorpus()));
      expect(
        (await access() as GroundPickerUnavailable).reason,
        GroundPickerBlock.notFound,
      );
      world.subTracks.seed(world.scope, [
        fixtureTrack(
          schoolId,
          'School',
          curriculumId: engineCurriculum,
          ended: true,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        (await access() as GroundPickerUnavailable).reason,
        GroundPickerBlock.ended,
      );
    });
  });

  group('inputs', () {
    test('own ground, other holders and learnt leaves stay distinct', () async {
      final corpus = mishnayosCorpus();
      start(
        GroundPickerWorld(
          corpus: corpus,
          tracks: [
            _school(const [berakhot1]),
            fixtureTrack(
              rebbeId,
              'Rebbe',
              curriculumId: engineCurriculum,
              ground: const [peah],
            ),
            fixtureTrack(
              ulidD,
              'Ended',
              curriculumId: engineCurriculum,
              ground: const [shabbat],
              ended: true,
            ),
          ],
          learnt: {...corpus.leavesUnder(berakhot2)},
        ),
      );
      final inputs = await ready();
      final model = inputs.model;
      final draft = GroundDraft.empty(model);
      expect(inputs.track.name, 'School');
      expect(model.rowOf(berakhot1, draft).inThisTrack, isTrue);
      expect(model.rowOf(peah, draft).inUseBy, ['Rebbe']);
      expect(model.rowOf(shabbat, draft).inUseBy, isEmpty);
      expect(model.rowOf(berakhot2, draft).isChazara, isTrue);
    });

    test('the engine holdsGround answer decides who is in use', () async {
      start(
        GroundPickerWorld(
          corpus: mishnayosCorpus(),
          tracks: [
            _school(),
            fixtureTrack(
              rebbeId,
              'Rebbe',
              curriculumId: engineCurriculum,
              ground: const [peah],
            ),
          ],
          subTrackStates: {
            rebbeId: const SubTrackState(
              subTrackId: rebbeId,
              holdsGround: false,
              inForecast: false,
              onHome: false,
            ),
          },
        ),
      );
      final model = (await ready()).model;
      expect(model.rowOf(peah, GroundDraft.empty(model)).inUseBy, isEmpty);
    });

    test(
      'an expired window the engine says no longer holds is not in use',
      () async {
        // Not ended, but its window closed (AD-34: today > window_end).
        start(
          GroundPickerWorld(
            corpus: mishnayosCorpus(),
            tracks: [
              _school(),
              fixtureTrack(
                rebbeId,
                'Rebbe',
                curriculumId: engineCurriculum,
                ground: const [peah],
                windowEnd: '2026-09-15',
              ),
            ],
            subTrackStates: {
              rebbeId: const SubTrackState(
                subTrackId: rebbeId,
                holdsGround: false,
                inForecast: false,
                onHome: false,
              ),
            },
          ),
        );
        final model = (await ready()).model;
        final draft = GroundDraft.empty(model);
        expect(model.rowOf(peah, draft).inUseBy, isEmpty);
      },
    );

    test('a live sub-track with no engine state is not in use', () async {
      start(
        GroundPickerWorld(
          corpus: mishnayosCorpus(),
          tracks: [
            _school(),
            fixtureTrack(
              rebbeId,
              'Rebbe',
              curriculumId: engineCurriculum,
              ground: const [peah],
            ),
          ],
          subTrackStates: const {},
        ),
      );
      final model = (await ready()).model;
      expect(model.rowOf(peah, GroundDraft.empty(model)).inUseBy, isEmpty);
    });

    test('a stored ground change recomputes the inputs', () async {
      start(GroundPickerWorld(corpus: mishnayosCorpus(), tracks: [_school()]));
      expect((await ready()).model.ownGround, isEmpty);
      world.subTracks.seed(world.scope, [
        _school(const [moed]),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect((await ready()).model.ownGround, [moed]);
    });

    test(
      'a learner state without the curriculum reads as nothing learnt',
      () async {
        final w = GroundPickerWorld(
          corpus: mishnayosCorpus(),
          tracks: [_school()],
        )..state = fakeLearnerState();
        start(w);
        final model = (await ready()).model;
        expect(
          model.rowOf(zeraim, GroundDraft.empty(model)).progress,
          TriState.empty,
        );
      },
    );
  });

  group('controller', () {
    test('Reset changes clears only the picks', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final provider = groundPickerControllerProvider(schoolId);
      c.listen(provider, (_, _) {});
      c.read(provider.notifier)
        ..setPicks({moed})
        ..setQuery('ber')
        ..setAvailableOnly(true)
        ..toggleExpanded(zeraim)
        ..reset();
      final s = c.read(provider);
      expect(s.picks, isEmpty);
      expect(s.query, 'ber');
      expect(s.availableOnly, isTrue);
      expect(s.expanded, {zeraim});
    });

    test('a rejected confirm drops the optimistic ground, keeps the picks', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final provider = groundPickerControllerProvider(schoolId);
      c.listen(provider, (_, _) {});
      final n = c.read(provider.notifier)
        ..setPicks({moed})
        ..submitting(const [moed]);
      expect(c.read(provider).optimisticGround, [moed]);
      expect(c.read(provider).submitting, isTrue);
      n.rejected();
      expect(c.read(provider).optimisticGround, isNull);
      expect(c.read(provider).submitting, isFalse);
      expect(c.read(provider).picks, {moed});
      n
        ..submitting(const [moed])
        ..accepted();
      expect(c.read(provider).picks, isEmpty);
      expect(c.read(provider).optimisticGround, isNull);
    });
  });

  test('the edit the picker sends is an append, never a replace', () {
    const edit = SubTrackEdit(appendGround: [moed]);
    expect(edit.ground, isNull);
    expect(edit.appendGround, [moed]);
  });
}
