/// Unit tests for [MainTrackIntent] and its member doc types.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  MainTrack track({
    MainTrackState state = MainTrackState.active,
    DateTime? endedAt,
  }) => MainTrack(curriculumId: 'mishnayos', state: state, endedAt: endedAt);

  test('only an active, non-ended track is evaluated (AD-35)', () {
    expect(
      MainTrackIntent(curriculumId: 'mishnayos', track: track()).isEvaluated,
      isTrue,
    );
    expect(
      MainTrackIntent(
        curriculumId: 'mishnayos',
        track: track(state: MainTrackState.retired),
      ).isEvaluated,
      isFalse,
    );
    expect(
      MainTrackIntent(
        curriculumId: 'mishnayos',
        track: track(endedAt: t0),
      ).isEvaluated,
      isFalse,
    );
  });

  test('a curriculum_tracks doc is required; duplicates rejected', () {
    expect(
      () => MainTrackIntent.fromStorageDocs('mishnayos', {}),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => MainTrackIntent.fromStorageDocs('mishnayos', {
        'curriculum_tracks/mishnayos': {
          'state': 'active',
          'curriculum_id': 'mishnayos',
        },
        'curriculum_scopes/a': {'curriculum_id': 'mishnayos'},
        'curriculum_scopes/b': {'curriculum_id': 'mishnayos'},
      }),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('curriculum_tracks / profile_programs doc id must equal curriculum', () {
    expect(
      () => MainTrack.fromStorage('tanach', {
        'state': 'active',
        'curriculum_id': 'mishnayos',
      }),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => MainTrackProgram.fromStorage('tanach', {
        'curriculum_id': 'mishnayos',
      }),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('tracking_start_date required with program_id and must be a date', () {
    expect(
      () => MainTrackProgram.fromStorage('mishnayos', {
        'curriculum_id': 'mishnayos',
        'program_id': 'mishna_yomit',
      }),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => MainTrackProgram.fromStorage('mishnayos', {
        'curriculum_id': 'mishnayos',
        'tracking_start_date': '2026-02-30',
      }),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('order entries require level/ref/user_sort_order/last_change_id', () {
    expect(
      () => MainTrackOrderEntry.fromStorage('d', {
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'legacy',
        'user_sort_order': 0,
      }),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('config docs reject a non-config collection', () {
    expect(
      () => MainTrackConfigDoc.fromStorage('goals', 'g', {
        'curriculum_id': 'mishnayos',
      }),
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => MainTrackIntent(
        curriculumId: 'mishnayos',
        track: track(),
        studyDays: [
          MainTrackConfigDoc(
            collection: MainTrackConfigDoc.stages,
            docId: 's',
            curriculumId: 'mishnayos',
            fields: const {},
          ),
        ],
      ),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('value equality of member docs', () {
    expect(track(), track());
    expect(
      MainTrackProgram(curriculumId: 'm', trackingStartRef: 'r'),
      MainTrackProgram(curriculumId: 'm', trackingStartRef: 'r'),
    );
  });
}
