// Mirror test for `lib/domain/learner_state/ports/ports.dart` (AG-5), sub-tracks story 1.1 (DNI-463).
//
// The library is an import-free placeholder until story 1.2 lands the
// learner-state contracts. What must hold from day one is AD-35 purity:
// the dependency-direction gate, run for real, reports no violation for
// this file. Checker-invoking (subprocess + output assertions), so it never
// reads lib/ source text itself (R7).
@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/ports.dart';

void main() {
  const libPath = 'lib/domain/learner_state/ports/ports.dart';
  final packageDir = Directory.current.path;

  test(' exists and the AD-35 pure-domain gate reports no '
      'violation for it', () async {
    expect(File('$packageDir/$libPath').existsSync(), isTrue);

    final result = await Process.run('dart', [
      'run',
      'tool/check_dependency_direction.dart',
      '--report',
    ], workingDirectory: packageDir);

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(
      result.stdout.toString(),
      allOf(
        contains('dependency-direction violation(s)'),
        isNot(contains(libPath)),
      ),
    );
  });

  test('the barrel exports every learner-state port (C0, DNI-524)', () {
    // Compile-time: each name resolves through ports.dart alone.
    expect(<Type>[
      ChangeLogRepository,
      CompleteRead,
      GovernedIntentRepository,
      LearnerScope,
      LearningEventRepository,
      LearningWritePort,
      OversizedGovernedWritePort,
      SubTrackRepository,
      TutorScopeGrantSource,
    ], hasLength(9));
  });
}
