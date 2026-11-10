import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';

void main() {
  final valid = <String, Object?>{
    'owner_uid': 'owner',
    'profile_id': 'profile',
    'display_name': 'Learner',
    'avatar_id': 2,
    'streak': {
      'by_curriculum': [
        {'curriculum_id': 'mishnah', 'current_days': 3, 'best_days': 7},
      ],
    },
    'current_tracks': [
      {
        'curriculum_id': 'mishnah',
        'display_name': 'Mishnah',
        'position': 'Berakhot 4',
      },
    ],
    'weekly_learning': {
      'by_curriculum': [
        {'curriculum_id': 'mishnah', 'limudim': 2, 'chazaros': 1},
      ],
    },
    'siyumim': [
      {'curriculum_id': 'mishnah', 'label': 'Berakhot', 'level': 'unit'},
    ],
    'computed_at': DateTime.utc(2026, 11, 10),
    'schema_version': 1,
  };

  test(
    'decodes the whitelisted profile projection and optional overall slot',
    () {
      final summary = SocialSummary.fromWire({
        ...valid,
        'streak': {
          ...valid['streak'] as Map<String, Object?>,
          'overall': {
            'curriculum_id': 'overall',
            'current_days': 4,
            'best_days': 9,
          },
        },
        'weekly_learning': {
          ...valid['weekly_learning'] as Map<String, Object?>,
          'overall': {'curriculum_id': 'overall', 'limudim': 8, 'chazaros': 2},
        },
      });

      expect(summary.streak.byCurriculum.single.currentDays, 3);
      expect(summary.streak.overall?.bestDays, 9);
      expect(summary.currentTracks.single.position, 'Berakhot 4');
      expect(summary.weeklyLearning.byCurriculum.single.chazaros, 1);
      expect(summary.weeklyLearning.overall?.limudim, 8);
      expect(summary.siyumim.single.label, 'Berakhot');
    },
  );

  test('rejects points and other private fields at every decoded level', () {
    expect(
      () => SocialSummary.fromWire({...valid, 'points': 100}),
      throwsFormatException,
    );
    expect(
      () => SocialSummary.fromWire({
        ...valid,
        'current_tracks': [
          {
            'curriculum_id': 'mishnah',
            'display_name': 'Mishnah',
            'position': null,
            'notes': 'private',
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => SocialSummary.fromWire({
        ...valid,
        'siyumim': [
          {
            'curriculum_id': 'mishnah',
            'label': 'Berakhot',
            'level': 'unit',
            'completed_at': '2026-11-10',
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
