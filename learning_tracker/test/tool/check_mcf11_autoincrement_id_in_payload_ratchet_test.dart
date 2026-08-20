// Tests for `tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`
// (Story 2.4, docs/planning/epics-firestore-migration-phase0.md — the
// MCF-11/AD-5 landmine sweep + standing gate).
//
// Mirrors the fixture-based approach in `check_edgeinsets_rtl_test.dart`:
// write a disposable fixture file directly into the checker's scanned
// directory (`lib/`, on a path outside `lib/core/sync/merge/` — the AC's
// exact "red-demo" requirement), run the script as a subprocess, assert the
// report flags the planted violation, then delete the fixture and assert a
// clean pass again. The tracked ratchet ceiling intentionally remains above
// today's live count, so one extra fixture does not make the gate exit 1.
// This checker-invoking test (Process.run + exit code/stdout assertions) never
// reads a lib/ file's source text into a Dart string itself (the
// checker subprocess does that, not this test file), so it does not
// consume R7 ratchet headroom (tool/check_r7_source_text_assertion_ratchet.
// dart only counts test/ files that read+assert on lib/ source text
// directly).
//
// setUp also guards against a prior killed run leaving the fixture behind
// (same crash-safety note the story flags for this exact fixture-in-lib/
// pattern).

@Tags(['serial-tools'])
// serial-tools: this test writes/deletes a fixture under learning_tracker/lib/
// while its checker recursively walks that same tree. It contends with the
// other real-lib fixture tests under the parallel main lane; run it through
// `make test-serial-tools` with --concurrency=1.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath =
      '$packageDir/tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart';
  final fixtureFile = File(
    '$packageDir/lib/features/scheduler/domain/models/'
    '_story_2_4_mcf11_landmine_fixture.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  Future<ProcessResult> runReport() => Process.run('dart', [
    'run',
    scriptPath,
    '--report',
  ], workingDirectory: packageDir);

  group('tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart '
      '(Story 2.4, MCF-11/AD-5)', () {
    setUp(() {
      // Guard against a prior failed/killed run leaving the fixture
      // behind in lib/ — see the story's crash-safety note for this
      // exact fixture-in-lib/ pattern.
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    tearDown(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    test('exits 0 on the real (fixed) tree, at the tracked baseline', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('MCF-11 autoincrement-id-in-payload ratchet passed'),
      );
    });

    test('lib/core/sync/merge/ itself is never counted, even though it is '
        'where the raw ids are legitimately consumed', () async {
      final result = await runReport();
      expect(
        result.stdout.toString(),
        isNot(contains('lib/core/sync/merge/')),
        reason:
            'the protected remap layer must be carved out entirely — '
            'stdout=${result.stdout}',
      );
    });

    test('AC (red-demo, "the grep must have teeth"): a fixture planting an '
        'autoincrement id inside a payload on a path outside merge/ appears '
        'in the report; deleting the fixture restores a clean pass', () async {
      // The exact MCF-4 shape: a device-local CurriculumTracks.id
      // (`trackId`) embedded verbatim under the `track_id` payload key,
      // on a path outside lib/core/sync/merge/ (here: a fresh feature
      // file, not even the same file as the known goal_entity.dart
      // finding already in the baseline).
      fixtureFile.writeAsStringSync('''
/// Story 2.4 red-demo fixture — deliberately reintroduces the MCF-11/MCF-4
/// landmine (a device-local Drift autoincrement id embedded in a synced
/// payload) on a path outside lib/core/sync/merge/. Deleted by the test's
/// tearDown; must never be committed.
library;

class StoryTwoFourLandmineFixture {
  const StoryTwoFourLandmineFixture({required this.trackId});

  final int trackId;

  Map<String, dynamic> toFirestore() => {
    'track_id': trackId,
  };
}
''');

      final withFixture = await runReport();
      expect(
        withFixture.stdout.toString(),
        allOf(
          contains('_story_2_4_mcf11_landmine_fixture.dart'),
          contains('track_id'),
        ),
        reason:
            'the report must expose a fresh track_id-from-trackId fixture '
            'outside merge/ even though the ratchet baseline still permits '
            'the additional site.\nstdout=${withFixture.stdout}',
      );

      fixtureFile.deleteSync();

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'deleting the fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
      expect(
        clean.stdout.toString(),
        contains('MCF-11 autoincrement-id-in-payload ratchet passed'),
      );
    });
  });
}
