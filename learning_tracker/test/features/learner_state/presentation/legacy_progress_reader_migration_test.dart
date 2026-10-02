// DNI-474 AC-2: a static audit of the R3 readers. Each one consumes
// LearnerState (directly, through the learner-progress providers, or as an
// engine value passed in) and none reads completions, the learning ledger
// or a legacy calculator; the two pace calculators and the
// CompletionDetectionService have no declaration or reference left.
//
// A repo-wide static audit over Directory('lib') (the R7 checker's
// documented tree-walking exemption).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The R3 readers named by AC-2 (both pace calculators are deleted).
const _readers = [
  'lib/features/progress/presentation/providers/progress_providers.dart',
  'lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart',
  'lib/features/progress/presentation/providers/items_learned_providers.dart',
  'lib/features/progress/presentation/providers/journey_providers.dart',
  'lib/features/progress/domain/services/chart_data_service.dart',
  'lib/features/progress/domain/services/curriculum_progress_service.dart',
  'lib/features/progress/domain/services/lifetime_tree_builder.dart',
  'lib/features/dashboard/domain/services/track_completion_service.dart',
  'lib/features/tracks/domain/services/track_progress_service.dart',
  'lib/features/tracks/setup/presentation/screens/track_detail_screen.dart',
  'lib/features/settings/presentation/screens/lifetime_marking_screen.dart',
];

/// Evidence a reader consumes the engine's state.
final _learnerState = RegExp(
  r'\b(LearnerState|CurriculumState|watchActiveLearnerState|'
  r'activeLearnerStateProvider|learner_progress(_providers)?\.dart)\b',
);

/// Legacy read paths a rewired reader must not use.
const _legacyReads = [
  'CompletionEntity',
  'completionRepositoryProvider',
  'getCompletionsByCurriculum',
  'getCompletionsByTier',
  'progressRepositoryProvider',
  'FirestoreChartDataRepositoryAdapter',
  'FirestoreProgressRepositoryAdapter',
  'learningLedgerProvider',
  'ref.watch(curriculumLedgerProvider',
  'computeLearnedLeafRefs',
  'completion_detection_service.dart',
  'pace_calculator.dart',
];

/// Symbols that must be gone from lib/ entirely.
final _retired = RegExp(
  r'\b(ProgressPaceCalculator|ProgressPaceStatus|PaceCalculator|'
  r'CompletionDetectionService|completionDetectionServiceProvider)\b',
);

Directory _lib() => Directory('lib').existsSync()
    ? Directory('lib')
    : Directory('learning_tracker/lib');

String _read(String path) {
  final file = File(path).existsSync()
      ? File(path)
      : File('learning_tracker/$path');
  return file.readAsStringSync();
}

/// [source] with `//` and `///` comment text blanked (string literals in
/// these files never contain `//`).
String _code(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  for (final path in _readers) {
    test('$path reads LearnerState and no legacy store', () {
      final code = _code(_read(path));
      expect(code, matches(_learnerState));
      for (final legacy in _legacyReads) {
        expect(code.contains(legacy), isFalse, reason: '$path uses $legacy');
      }
    });
  }

  test('the pace calculators and CompletionDetectionService are gone', () {
    for (final path in [
      'lib/features/progress/domain/services/pace_calculator.dart',
      'lib/features/scheduler/domain/services/pace_calculator.dart',
      'lib/features/learning/domain/services/completion_detection_service.dart',
    ]) {
      expect(
        File(path).existsSync() || File('learning_tracker/$path').existsSync(),
        isFalse,
        reason: '$path must be deleted',
      );
    }
    final hits = <String>[];
    for (final entity in _lib().listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_retired.hasMatch(_code(entity.readAsStringSync()))) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty, reason: 'no declaration or code reference remains');
  });
}
