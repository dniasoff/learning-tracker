// Mirror test for `lib/domain/learner_state/ports/governed_doc_reader.dart`
// (DNI-470): the in-memory fake every governed command test reads through
// honours the port contract (copies, null when absent).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

void main() {
  test(
    'a doc reads as a copy, null when absent; an unknown entry is null',
    () async {
      final store = InMemoryChangeLogRepository()
        ..seedDoc(c0Scope(), 'goals', 'g', {'pace_value': 1});
      final GovernedDocReader reader = store;

      final doc = await reader.currentDoc(c0Scope(), 'goals', 'g');
      expect(doc, {'pace_value': 1});
      doc!['pace_value'] = 2;
      expect(await reader.currentDoc(c0Scope(), 'goals', 'g'), {
        'pace_value': 1,
      });
      expect(await reader.currentDoc(c0Scope(), 'goals', 'other'), isNull);
      expect(await reader.entry(c0Scope(), ulidA), isNull);
    },
  );
}
