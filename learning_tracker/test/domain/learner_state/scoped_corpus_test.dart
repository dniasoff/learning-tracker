// Mirror test for `lib/domain/learner_state/scoped_corpus.dart` (DNI-465
// T2: AD-42 `ContentIndex ∩ curriculum_scope`).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/scoped_corpus.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();

  test('no scope is the whole corpus', () {
    expect(scopedLeaves(corpus, null), corpus.leaves);
  });

  test('a {level, ref} scope selects that node', () {
    final scope = engineScope({'level': 'masechta', 'ref': 'Mishnah Peah'});
    expect(resolveScopeNode(corpus, scope), peah);
    expect(scopedLeaves(corpus, scope), [
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
    ]);
  });

  test('a legacy {scope_level, scope_value} scope resolves by depth', () {
    final seder = engineScope({'scope_level': 1, 'scope_value': 'Seder Moed'});
    expect(resolveScopeNode(corpus, seder), moed);
    expect(scopedLeaves(corpus, seder), [
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
    ]);
    final masechta = engineScope({
      'scope_level': 2,
      'scope_value': 'Mishnah Berakhot',
    });
    expect(resolveScopeNode(corpus, masechta), berakhot);
  });

  test('an unresolvable scope yields no leaves, never the whole corpus', () {
    for (final fields in <Map<String, Object?>>[
      {'scope_level': 1, 'scope_value': 'Mishnah Berakhot'}, // wrong depth
      {'scope_level': 3, 'scope_value': '1'}, // positional label
      {'level': 'masechta', 'ref': 'Mishnah Nope'},
      {'unexpected': true},
    ]) {
      final scope = engineScope(fields);
      expect(resolveScopeNode(corpus, scope), isNull, reason: '$fields');
      expect(scopedLeaves(corpus, scope), isEmpty, reason: '$fields');
    }
  });

  test('an ended scope doc is no scope', () {
    final ended = MainTrackConfigDoc(
      collection: MainTrackConfigDoc.scope,
      docId: 'x',
      curriculumId: engineCurriculum,
      fields: const {'level': 'masechta', 'ref': 'Mishnah Peah'},
      endedAt: engineAt(1),
    );
    expect(scopedLeaves(corpus, ended), corpus.leaves);
  });
}
