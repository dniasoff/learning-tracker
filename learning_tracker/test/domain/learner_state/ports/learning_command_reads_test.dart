// Mirror test for
// `lib/domain/learner_state/ports/learning_command_reads.dart` (DNI-469).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';

final class _Points implements PointsAmountReader {
  final asked = <(LearnerScope, String, int?)>[];

  @override
  Future<int> pointsAmount(LearnerScope s, String c, int? stage) async {
    asked.add((s, c, stage));
    return 3;
  }
}

void main() {
  test('LearningCommandReadsFrom delegates each read', () async {
    final corpus = mishnayosCorpus();
    final points = _Points();
    final scopes = <LearnerScope>[];
    final reads = LearningCommandReadsFrom(
      settingsHistory: (s) async {
        scopes.add(s);
        return c0SettingsHistory();
      },
      events: (s) async {
        scopes.add(s);
        return [engineLearn(1, 'r')];
      },
      corpus: (c) async => <String, Corpus>{engineCurriculum: corpus}[c],
      points: points,
    );
    final scope = c0Scope();
    expect(await reads.settingsHistory(scope), c0SettingsHistory());
    expect(await reads.events(scope), [engineLearn(1, 'r')]);
    expect(await reads.corpus(engineCurriculum), same(corpus));
    expect(await reads.corpus('other'), isNull);
    expect(await reads.pointsAmount(scope, engineCurriculum, 2), 3);
    expect(scopes, [scope, scope]);
    expect(points.asked, [(scope, engineCurriculum, 2)]);
  });
}
