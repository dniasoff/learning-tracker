import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';

void main() {
  final valid = <String, Object?>{
    'display_name': 'Learner',
    'avatar_id': 2,
    'streak': {
      'by_curriculum': [
        {'curriculum_id': 'mishnayos', 'current_days': 3, 'best_days': 7},
      ],
    },
    'current_tracks': [
      {'curriculum_id': 'mishnayos', 'position_ref': 'Berakhot 4'},
    ],
    'weekly_learning': {
      'week_start': '2026-11-08',
      'by_curriculum': [
        {'curriculum_id': 'mishnayos', 'limudim': 2, 'chazaros': 1},
      ],
    },
    'siyumim': [
      {'curriculum_id': 'mishnayos', 'ref': 'Berakhot', 'level': 'masechta'},
    ],
    'computed_at': DateTime.utc(2026, 11, 10),
    'schema_version': 1,
  };

  test('decodes identifier-only projection and the future overall slots', () {
    final summary = SocialSummary.fromWire({
      ...valid,
      'streak': {
        'by_curriculum': [
          {'curriculum_id': 'mishnayos', 'current_days': 3, 'best_days': 7},
        ],
        'overall': {'current_days': 4, 'best_days': 9},
      },
      'weekly_learning': {
        'week_start': '2026-11-08',
        'by_curriculum': [
          {'curriculum_id': 'mishnayos', 'limudim': 2, 'chazaros': 1},
        ],
        'overall': {'limudim': 8, 'chazaros': 2},
      },
    });

    expect(summary.streak.byCurriculum.single.currentDays, 3);
    expect(summary.streak.overall?.bestDays, 9);
    expect(summary.currentTracks.single.positionRef, 'Berakhot 4');
    expect(summary.weeklyLearning.weekStart, '2026-11-08');
    expect(summary.weeklyLearning.byCurriculum.single.chazaros, 1);
    expect(summary.weeklyLearning.overall?.limudim, 8);
    expect(summary.siyumim.single.ref, 'Berakhot');
  });

  test('rejects private fields and any client-authored labels', () {
    expect(
      () => SocialSummary.fromWire({...valid, 'points': 100}),
      throwsFormatException,
    );
    expect(
      () => SocialSummary.fromWire({...valid, 'owner_uid': 'account-id'}),
      throwsFormatException,
    );
    expect(
      () => SocialSummary.fromWire({
        ...valid,
        'current_tracks': [
          {
            'curriculum_id': 'mishnayos',
            'position_ref': 'Berakhot 4',
            'display_name': 'Injected label',
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
            'curriculum_id': 'mishnayos',
            'ref': 'Berakhot',
            'level': 'masechta',
            'label': 'Injected text',
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'rejects unknown curricula, malformed refs and non-Sunday week starts',
    () {
      expect(
        () => SocialSummary.fromWire({
          ...valid,
          'current_tracks': [
            {'curriculum_id': 'unknown', 'position_ref': null},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => SocialSummary.fromWire({
          ...valid,
          'current_tracks': [
            {'curriculum_id': 'mishnayos', 'position_ref': '../private'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => SocialSummary.fromWire({
          ...valid,
          'weekly_learning': {
            'week_start': '2026-11-10',
            'by_curriculum': <Object?>[],
          },
        }),
        throwsFormatException,
      );
    },
  );
}
