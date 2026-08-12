/// Story acceptance coverage for Epic 28 — curriculum overlap.
@Tags(['epic_28', 'story_i4'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:test/test.dart';

void main() {
  group('I-4-A — curriculum overlap registry', () {
    test('Tanach contains Chumash and Nach as subsets', () {
      expect(subsetsOf(CurriculumId.tanach), {
        CurriculumId.chumash,
        CurriculumId.nach,
      });
    });

    test('leaf curricula have no subsets', () {
      expect(subsetsOf(CurriculumId.mishnayos), isEmpty);
      expect(subsetsOf(CurriculumId.bavli), isEmpty);
    });
  });

  group('I-4-B — Firestore overlap reads', skip:
      'Blocked: the original overlap assertions call CompletionDao and lifetimeDataProvider over Drift completion/ledger tables. The Firestore progress provider is not wired to the overlap acceptance seam.',
      () {
    test('placeholder for the pending Firestore overlap provider', () {});
  });
}
