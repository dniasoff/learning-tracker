// Mirror test for `lib/domain/learner_state/governed_change.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';

void main() {
  GovernedEntityChange change({Object? rate = 7}) => GovernedEntityChange(
    entity: GovernedEntity.mainTrackProgram,
    entityId: 'mishnayos',
    docs: [
      GovernedDocPatch(
        collection: 'profile_programs',
        docId: 'mishnayos',
        fields: {'rate': rate},
      ),
    ],
  );

  test('GovernedDocPatch defaults to upsert', () {
    const p = GovernedDocPatch(collection: 'c', docId: 'd', fields: {});
    expect(p.mode, DocMode.upsert);
  });

  test('GovernedAction keeps action order and rejects an empty action', () {
    final a = GovernedAction([change(), change(rate: null)]);
    expect(a.changes.last.docs.single.fields, {'rate': null});
    expect(() => a.changes.add(change()), throwsUnsupportedError);
    expect(() => GovernedAction(const []), throwsArgumentError);
  });

  test('value equality over storage-form fields', () {
    expect(change(), change());
    expect(change().hashCode, change().hashCode);
    expect(change(), isNot(change(rate: 8)));
    expect(GovernedAction([change()]), GovernedAction([change()]));
  });
}
