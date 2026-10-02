/// DNI-470 (C0 stub map): `FirestoreGovernedIntentRepository` emits the
/// complete governed intent only once every collection and the settings
/// are in, and assembles it as a tolerant projection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_governed_intent_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_settings_reader.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _profile = 'users/owner-uid/learner_profiles/$profileUlid';

Future<void> _seed(
  FirebaseFirestore fs,
  String path,
  Map<String, Object?> data,
) => fs.doc('$_profile/$path').set(data);

void main() {
  test('nothing before the settings and every collection are in; then the '
      'assembled intent', () async {
    final fs = FakeFirebaseFirestore();
    await _seed(fs, 'curriculum_tracks/mishnayos', {
      'curriculum_id': 'mishnayos',
      'state': 'active',
      'updated_at': '2020-01-01', // retired key: ignored
    });
    await _seed(fs, 'profile_programs/mishnayos', {
      'curriculum_id': 'mishnayos',
      'program_id': 'daf',
      'tracking_start_date': '2026-09-01',
    });
    await _seed(fs, 'track_learning_order/o1', {
      'curriculum_id': 'mishnayos',
      'level': 'mishna',
      'ref': 'Mishnah Berakhot 1:1',
      'user_sort_order': 0,
      'last_change_id': ulidA,
    });
    await _seed(fs, 'study_day_configs/s1', {
      'curriculum_id': 'mishnayos',
      'day_of_week': 1,
      'day_type': 'study',
    });
    await _seed(fs, 'goals/mishnayos_deadline', {
      'goal_type': 'deadline',
      'target_date': '2027-06-01',
      'curriculum_id': 'mishnayos',
    });
    await _seed(fs, 'goals/legacy-goal-1', {
      'goal_type': 'deadline',
      'target_date': '2027-06-01',
      'curriculum_id': 'mishnayos',
    });
    // A legacy track without curriculum_id and an orphan order doc.
    await _seed(fs, 'curriculum_tracks/legacy', {'state': 'active'});
    await _seed(fs, 'track_learning_order/o2', {'ref': 'x'});

    final repo = FirestoreGovernedIntentRepository(
      firestore: fs,
      settings: FirestoreLearnerSettingsReader(firestore: fs),
    );
    final seen = <LearnerIntent>[];
    final errors = <Object>[];
    final sub = repo.watch(c0Scope()).listen(seen.add, onError: errors.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen, isEmpty, reason: 'no profile settings: never a guess');
    expect(errors.single, isA<LearnerProfileMissingException>());

    await fs.doc(_profile).set({'time_zone': 'Asia/Jerusalem'});
    for (var i = 0; i < 10 && seen.isEmpty; i++) {
      await pumpEventQueue();
    }

    final intent = seen.single;
    expect(
      intent.settings,
      const LearnerSettings(profileId: profileUlid, timeZone: 'Asia/Jerusalem'),
    );
    expect(intent.mainTracks.keys, ['mishnayos']);
    final track = intent.mainTracks['mishnayos']!;
    expect(track.track.state, MainTrackState.active);
    expect(track.program?.programId, 'daf');
    expect(track.order.single.docId, 'o1');
    expect(track.studyDays.single.docId, 's1');
    expect(
      intent.goals['mishnayos'],
      const CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: 'mishnayos',
          targetDate: '2027-06-01',
        ),
      ),
    );
  });

  test('a curriculum whose docs cannot assemble is left out; other '
      'curricula still arrive', () {
    final intent = FirestoreGovernedIntentRepository.assemble(c0Settings, {
      'curriculum_tracks': [
        (id: 'a', data: {'curriculum_id': 'a', 'state': 'active'}),
        (id: 'b', data: {'curriculum_id': 'b', 'state': 'active'}),
      ],
      // Two scope docs for curriculum b: cannot assemble.
      'curriculum_scopes': [
        (id: 's1', data: {'curriculum_id': 'b', 'scope_level': 1}),
        (id: 's2', data: {'curriculum_id': 'b', 'scope_level': 2}),
      ],
      // A program doc its codec rejects (program without a start date) is
      // left out on its own; curriculum a still assembles.
      'profile_programs': [
        (id: 'a', data: {'curriculum_id': 'a', 'program_id': 'daf'}),
      ],
      'goals': [
        (
          id: 'a_pace',
          data: {
            'goal_type': 'pace',
            'pace_value': 2,
            'pace_unit': 'mishnah',
            'pace_granularity': 'day',
            'curriculum_id': 'a',
          },
        ),
      ],
    });
    expect(intent.mainTracks.keys, ['a']);
    expect(intent.mainTracks['a']!.program, isNull);
    expect(intent.goals['a']?.pace?.paceValue, 2);
    expect(intent.goals['a']?.deadline, isNull);
  });
}
