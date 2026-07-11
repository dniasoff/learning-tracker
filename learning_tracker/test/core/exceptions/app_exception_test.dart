// Tests for the shared CauseSuffix mixin — AUD-core-sync-32.
//
// Regression coverage for the toString() de-duplication: the ternary
// `cause != null ? ' caused by: $cause' : ''` used to be hand-copied into
// FirestorePermissionDeniedException, MergeException, and
// OutboxDeadLetterException (the latter two since deleted as dead code by
// AUD-core-sync-27). This locks in that the single shared implementation
// still produces byte-identical output for both the cause-present and
// cause-absent cases.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

class _WithCause with CauseSuffix {
  _WithCause(this.cause);

  @override
  final Object? cause;
}

void main() {
  group('CauseSuffix', () {
    test('causeSuffix is empty when cause is null', () {
      expect(_WithCause(null).causeSuffix, '');
    });

    test('causeSuffix formats a non-null cause', () {
      final ex = _WithCause(Exception('boom'));
      expect(ex.causeSuffix, ' caused by: Exception: boom');
    });
  });
}
