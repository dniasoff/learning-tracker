// AUD-tutoring-03 — no duplicate `incomingTutorGrantsProvider` definition.
//
// Regression for the P1 finding: tutor_grant_providers.dart (a @riverpod
// codegen provider, network-only, no offline reconciliation) and
// manage_tutors_providers.dart (a hand-written FutureProvider, offline-first
// — the one every tutoring/profile screen actually watches) both defined a
// top-level symbol named `incomingTutorGrantsProvider`. Two same-named
// providers force every consumer that needs symbols from both files to
// `show`/`hide`/alias-import around the collision, and any new file that
// imports the `tutoring.dart` barrel (which re-exports tutor_grant_providers,
// not manage_tutors_providers) gets the inferior network-only version with
// no offline reconciliation — silently reintroducing the exact bug class
// accept_invite_screen.dart's now-removed `as manage_tutors` alias existed
// to work around.
//
// `make audit`'s existing AG-4 duplicate-symbol grep only scans
// class/enum/mixin declarations — it does not catch a duplicate top-level
// `final` provider variable, so this collision needed a dedicated regression
// test rather than relying on that checker.

@Tags(['tutoring', 'aud_tutoring_03'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('incomingTutorGrantsProvider is defined exactly once under '
      'lib/features/tutoring/', () {
    final tutoringDir = Directory('lib/features/tutoring');
    final definitionSites = <String>[];

    for (final entity in tutoringDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Generated files are derived from their source .dart file — scanning
      // them would double-count a definition already found in the source.
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      final content = entity.readAsStringSync();
      // Matches both the @riverpod codegen function-declaration form
      // (`Future<...> incomingTutorGrants(Ref ref)`) and a hand-written
      // top-level provider declaration
      // (`final incomingTutorGrantsProvider = ...`).
      final isCodegenDeclaration = RegExp(
        r'\bincomingTutorGrants\s*\(\s*Ref\s+ref\s*\)',
      ).hasMatch(content);
      final isHandWrittenDeclaration = RegExp(
        r'\bfinal\s+incomingTutorGrantsProvider\s*=',
      ).hasMatch(content);
      if (isCodegenDeclaration || isHandWrittenDeclaration) {
        definitionSites.add(entity.path);
      }
    }

    expect(
      definitionSites,
      hasLength(1),
      reason:
          'incomingTutorGrantsProvider must be defined in exactly one file '
          'under lib/features/tutoring/ (found: $definitionSites). A second '
          'definition reintroduces the AUD-tutoring-03 name collision.',
    );
    expect(
      definitionSites.single,
      'lib/features/tutoring/presentation/providers/manage_tutors_providers.dart',
      reason:
          'The offline-first provider in manage_tutors_providers.dart is '
          'canonical — it is the one every tutoring/profile screen '
          'actually watches (reconciles the CF result against the '
          'locally-mirrored tutored profiles, D18).',
    );
  });

  test(
    'accept_invite_screen.dart no longer aliases manage_tutors_providers.dart '
    'to disambiguate a naming collision',
    () {
      final src = File(
        'lib/features/tutoring/presentation/screens/accept_invite_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        isNot(contains('as manage_tutors')),
        reason:
            'The alias workaround existed only because of the duplicate '
            'incomingTutorGrantsProvider definition (AUD-tutoring-03). Now '
            'that the duplicate is gone, the alias is dead weight.',
      );
      expect(
        src,
        contains('incomingTutorGrantsProvider'),
        reason:
            'The screen must still read/invalidate incomingTutorGrantsProvider '
            '(now unambiguously the manage_tutors_providers one).',
      );
    },
  );
}
