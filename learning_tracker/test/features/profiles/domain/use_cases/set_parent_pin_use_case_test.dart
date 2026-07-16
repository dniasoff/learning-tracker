/// Unit tests for [SetParentPinUseCase] — AUD-core-domain-05.
///
/// AUD-core-domain-05 found `set_parent_pin_use_case.dart` hand-rolling its
/// own `^\d{4}$` PIN-format regex instead of routing through the
/// `Pin` value object (`core/domain/value_objects/pin.dart`) that already
/// implements the identical invariant — two unlinked sources of truth for
/// the same 4-digit-PIN rule. These tests pin down both:
///  1. the wiring itself (the use case's source now imports and defers to
///     `Pin` rather than a private duplicate regex), and
///  2. behavioral parity with `Pin.tryParse` across the same boundary cases
///     `pin_test.dart` exercises for `Pin` directly.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/pin.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/domain/use_cases/set_parent_pin_use_case.dart';

import '../../../../helpers/fake_secure_storage.dart';

void main() {
  group('SetParentPinUseCase', () {
    // -------------------------------------------------------------------
    // AC1/AC2 — wiring: the source no longer hand-rolls a duplicate
    // digit-format regex; it imports and defers to Pin.
    // -------------------------------------------------------------------
    group('wiring (AUD-core-domain-05)', () {
      final source = File(
        'lib/features/profiles/domain/use_cases/set_parent_pin_use_case.dart',
      ).readAsStringSync();

      test('imports the Pin value object', () {
        expect(
          source,
          contains(
            "import 'package:learning_tracker/core/domain/value_objects/pin.dart';",
          ),
        );
      });

      test('validates via Pin rather than a private hand-rolled regex', () {
        expect(source, contains('Pin.'));
        // The pre-fix implementation hand-rolled its own copy of Pin's
        // invariant as `RegExp(r'^\d{4}$')` in a private `_isNumeric`
        // helper. That duplicate must be gone now that Pin is the single
        // source of truth for the 4-digit-PIN invariant.
        expect(source, isNot(contains(r'^\d{4}$')));
        expect(source, isNot(contains('_isNumeric')));
      });
    });

    // -------------------------------------------------------------------
    // AC2 — behavioral parity with Pin.tryParse across the same boundary
    // cases pin_test.dart exercises for Pin directly.
    // -------------------------------------------------------------------
    group('validation parity with Pin', () {
      late SetParentPinUseCase useCase;

      setUp(() {
        final storage = createMockStorage();
        useCase = SetParentPinUseCase(PinService(storage));
      });

      const cases = <String>[
        '1234', // valid
        '0000', // valid
        '123', // too short
        '12345', // too long
        '', // empty
        '12ab', // non-digit
        '12 4', // embedded space
        ' 123', // whitespace-padded
      ];

      for (final candidate in cases) {
        final expectValid = Pin.tryParse(candidate) != null;

        test(
          '"$candidate" -> ${expectValid ? "success" : "validation failure"} '
          '(matches Pin.tryParse)',
          () async {
            final result = await useCase.call(profileId: 1, pin: candidate);
            expect(
              result,
              expectValid
                  ? isA<SetPinSuccess>()
                  : isA<SetPinValidationFailure>(),
            );
          },
        );
      }
    });
  });
}
