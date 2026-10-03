// The tracks feature's curriculum-scope write adapter: delegates to the
// active learner's FirestoreCurriculumScopeRepository and refuses to write
// before an account and learner profile are active.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_scope_write_repository_impl.dart';

import '../../../../../helpers/firestore_fake.dart';
import '../../../../../helpers/firestore_governed_writer.dart';

const _uid = 'uid-scope-write';

final _adapterProvider =
    Provider<FirestoreCurriculumScopeWriteRepositoryAdapter>(
      (ref) => FirestoreCurriculumScopeWriteRepositoryAdapter(ref: ref),
    );

void main() {
  test(
    'inserts and clears scopes through the active learner repository',
    () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final repo = FirestoreCurriculumScopeRepository(
        firestore: firestore,
        uid: _uid,
        profileId: governedTestProfileId,
        writer: FirestoreGovernedWriter(firestore, uid: _uid),
      );
      final container = ProviderContainer.test(
        overrides: [
          firestoreCurriculumScopeRepositoryProvider.overrideWith(
            (ref) async => repo,
          ),
        ],
      );
      final adapter = container.read(_adapterProvider);

      await adapter.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      );
      expect(await repo.getScopeValues(CurriculumId.mishnayos), [
        'Seder Zeraim',
      ]);

      await adapter.clearScopes(CurriculumId.mishnayos);
      expect(await repo.hasScopes(CurriculumId.mishnayos), isFalse);
    },
  );

  test('throws the not-ready exception with no active learner', () async {
    final container = ProviderContainer.test(
      overrides: [
        firestoreCurriculumScopeRepositoryProvider.overrideWith(
          (ref) async => null,
        ),
      ],
    );
    final adapter = container.read(_adapterProvider);

    await expectLater(
      adapter.clearScopes(CurriculumId.mishnayos),
      throwsA(isA<CurriculumScopeWriteRepositoryNotReadyException>()),
    );
    await expectLater(
      adapter.insertScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: [(level: 1, value: 'Seder Zeraim')],
      ),
      throwsA(isA<CurriculumScopeWriteRepositoryNotReadyException>()),
    );
    expect(
      const CurriculumScopeWriteRepositoryNotReadyException().toString(),
      contains('cannot write a scope selection'),
    );
  });
}
