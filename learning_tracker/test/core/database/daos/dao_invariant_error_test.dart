// Tests for DaoInvariantError / DaoErrorCode (AUD-core-database-14, EH-5).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';

void main() {
  group('DaoInvariantError', () {
    test('is an Error, not a plain Exception', () {
      // EH-4: these signal a programming error and should crash loudly,
      // matching the StateError semantics they replaced — never caught as
      // normal control flow.
      expect(DaoInvariantError(DaoErrorCode.unknownAccountTier), isA<Error>());
    });

    test('carries the given code', () {
      final error = DaoInvariantError(DaoErrorCode.lastActiveCurriculum);
      expect(error.code, DaoErrorCode.lastActiveCurriculum);
      expect(error.debugDetail, isNull);
    });

    test('carries an optional debugDetail', () {
      final error = DaoInvariantError(DaoErrorCode.studyDayTrackNotFound, 9999);
      expect(error.code, DaoErrorCode.studyDayTrackNotFound);
      expect(error.debugDetail, 9999);
    });

    test('toString() carries the code name but never a pre-formatted English '
        'sentence (EH-5)', () {
      final error = DaoInvariantError(DaoErrorCode.unknownAccountTier);
      expect(error.toString(), contains('unknownAccountTier'));
      // The whole point of EH-5: no free-text message field/sentence.
      expect(error.toString(), isNot(contains(' the ')));
    });

    test('toString() includes debugDetail when present', () {
      final error = DaoInvariantError(
        DaoErrorCode.ledgerInsertCollisionUnresolvable,
        'some-id',
      );
      expect(error.toString(), contains('some-id'));
    });

    test('can be thrown and caught as DaoInvariantError', () {
      expect(
        () => throw DaoInvariantError(DaoErrorCode.unknownAccountTier),
        throwsA(isA<DaoInvariantError>()),
      );
    });
  });

  group('DaoErrorCode', () {
    test('has exactly the 4 codes this finding introduced', () {
      expect(DaoErrorCode.values, hasLength(4));
      expect(
        DaoErrorCode.values,
        containsAll(<DaoErrorCode>[
          DaoErrorCode.lastActiveCurriculum,
          DaoErrorCode.ledgerInsertCollisionUnresolvable,
          DaoErrorCode.studyDayTrackNotFound,
          DaoErrorCode.unknownAccountTier,
        ]),
      );
    });
  });
}
