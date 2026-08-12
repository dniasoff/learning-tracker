import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

class _Eligibility implements CurriculumRewardEligibility {
  _Eligibility(this.eligible);
  final Set<CurriculumId> eligible;

  @override
  Future<bool> isEligible(CurriculumId curriculumId) async =>
      eligible.contains(curriculumId);
}

class _Balance implements PointsBalanceReader {
  _Balance(this.value);
  final int value;

  @override
  Future<int> getBalance() async => value;
}

CompletionEntity _completion(
  CurriculumId curriculumId,
  String ref,
  int points, {
  DateTime? at,
}) => CompletionEntity(
  curriculumId: curriculumId,
  sefariaRef: ref,
  stageId: 1,
  trackType: 'personal',
  source: CompletionSource.live,
  completedAt: at ?? DateTime.utc(2026, 3, 1),
  points: points,
);

void main() {
  final service = PointsService(
    eligibility: _Eligibility({CurriculumId.mishnayos}),
    balanceReader: _Balance(37),
  );

  test(
    'getCurriculumTotal sums positive points only for eligible curricula',
    () async {
      final completions = [
        _completion(CurriculumId.mishnayos, '1', 10),
        _completion(CurriculumId.mishnayos, '2', 0),
        _completion(CurriculumId.bavli, '3', 99),
      ];

      expect(
        await service.getCurriculumTotal(CurriculumId.mishnayos, completions),
        10,
      );
      expect(
        await service.getCurriculumTotal(CurriculumId.bavli, completions),
        0,
      );
    },
  );

  test(
    'derived and breakdown totals use CurriculumId as the sole track key',
    () async {
      final completions = [
        _completion(CurriculumId.mishnayos, '1', 10),
        _completion(CurriculumId.mishnayos, '2', 15),
      ];

      expect(await service.getDerivedTotal(completions), 25);
      expect(await service.getCurriculumBreakdown(completions), {
        CurriculumId.mishnayos: 25,
      });
    },
  );

  test('global total reads the debitable balance port', () async {
    expect(await service.getGlobalTotal(), 37);
  });

  test(
    'points history filters by curriculum and orders newest first',
    () async {
      final older = _completion(
        CurriculumId.mishnayos,
        'older',
        5,
        at: DateTime.utc(2026, 3, 1),
      );
      final newer = _completion(
        CurriculumId.mishnayos,
        'newer',
        8,
        at: DateTime.utc(2026, 3, 2),
      );

      final history = await service.getPointsHistory(
        completions: [older, newer],
        curriculumId: CurriculumId.mishnayos,
      );
      expect(history.map((entry) => entry.sefariaRef), ['newer', 'older']);
      expect(history.first.points, 8);
    },
  );
}
