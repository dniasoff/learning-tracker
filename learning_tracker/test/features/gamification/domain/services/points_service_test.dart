// Mirror test for `lib/features/gamification/domain/services/points_service.dart`
// (DNI-480): the service reads the AD-50 filtered balance and the counted
// awards; it no longer reads completions or a curriculum eligibility gate.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';

class _Balance implements PointsBalanceReader {
  _Balance(this.value);
  final int value;

  @override
  Future<int> getBalance() async => value;
}

class _Earned implements EarnedPointsReader {
  _Earned(this.awards);
  final List<EarnedPoints> awards;

  @override
  Future<List<EarnedPoints>> getEarnedPoints() async => awards;
}

void main() {
  test('global total reads the filtered balance port', () async {
    final service = PointsService(
      balanceReader: _Balance(37),
      earnedReader: _Earned(const []),
    );
    expect(await service.getGlobalTotal(), 37);
  });

  test('the breakdown sums counted awards per curriculum', () async {
    final service = PointsService(
      balanceReader: _Balance(0),
      earnedReader: _Earned(const [
        EarnedPoints(
          eventId: 'a',
          curriculumId: CurriculumId.mishnayos,
          points: 10,
        ),
        EarnedPoints(
          eventId: 'b',
          curriculumId: CurriculumId.mishnayos,
          points: 15,
        ),
        EarnedPoints(eventId: 'c', curriculumId: CurriculumId.bavli, points: 4),
        EarnedPoints(eventId: 'd', curriculumId: CurriculumId.bavli, points: 0),
      ]),
    );
    expect(await service.getCurriculumBreakdown(), {
      CurriculumId.mishnayos: 25,
      CurriculumId.bavli: 4,
    });
  });

  test('a curriculum with no counted award is absent', () async {
    final service = PointsService(
      balanceReader: _Balance(0),
      earnedReader: _Earned(const []),
    );
    expect(await service.getCurriculumBreakdown(), isEmpty);
  });
}
