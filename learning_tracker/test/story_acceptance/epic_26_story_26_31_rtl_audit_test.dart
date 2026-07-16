/// Story acceptance tests for Story 26.31 (DNI-374) — RTL audit: migrate
/// LTR-only widget callsites to directional variants in lib/features/.
///
/// AC1: No `EdgeInsets.only(` with `left:` or `right:` in lib/features/.
/// AC2: No `Alignment.centerLeft` or `Alignment.centerRight` in lib/features/.
/// AC3: No `TextAlign.left` or `TextAlign.right` in lib/features/.
/// AC4: AlignmentDirectional and EdgeInsetsDirectional are used in migrated
///      files (positive guard to confirm replacements landed).
@Tags(['epic_26', 'story_26_31'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/lib_source.dart';

Iterable<File> _dartFilesUnder(Directory root) sync* {
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

void main() {
  late Directory featuresDir;

  setUpAll(() {
    final root = projectRoot();
    featuresDir = Directory('${root.path}/lib/features');
    if (!featuresDir.existsSync()) {
      throw StateError('lib/features/ not found under ${root.path}');
    }
  });

  // ────────────────────────────────────────────────────────────────────────────
  // AC1 — no EdgeInsets.only(left: ...) or EdgeInsets.only(right: ...) in
  //        lib/features/ (must use EdgeInsetsDirectional.only(start:/end:))
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 26.31 AC1 — EdgeInsets.only with left:/right: replaced',
    tags: ['story_26_31'],
    () {
      test(
        'no EdgeInsets.only(left: or EdgeInsets.only(right: in lib/features/',
        () {
          final offenders = <String>[];
          final pattern = RegExp(r'EdgeInsets\.only\([^)]*\b(left|right):');

          for (final f in _dartFilesUnder(featuresDir)) {
            if (f.path.endsWith('.g.dart') ||
                f.path.endsWith('.freezed.dart') ||
                f.path.endsWith('.mocks.dart')) {
              continue;
            }
            final src = f.readAsStringSync();
            if (pattern.hasMatch(src)) {
              // Collect line numbers for easier diagnosis.
              var lineNo = 0;
              for (final line in src.split('\n')) {
                lineNo++;
                if (pattern.hasMatch(line)) {
                  offenders.add('${f.path}:$lineNo — $line');
                }
              }
            }
          }

          expect(
            offenders,
            isEmpty,
            reason:
                'AC1: EdgeInsets.only with left:/right: is not RTL-safe. '
                'Use EdgeInsetsDirectional.only(start:/end:) instead.\n'
                '${offenders.join('\n')}',
          );
        },
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC2 — no Alignment.centerLeft or Alignment.centerRight in lib/features/
  //        (must use AlignmentDirectional.centerStart / centerEnd)
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 26.31 AC2 — Alignment.centerLeft/centerRight replaced',
    tags: ['story_26_31'],
    () {
      test(
        'no Alignment.centerLeft or Alignment.centerRight in lib/features/',
        () {
          final offenders = <String>[];
          final pattern = RegExp(r'Alignment\.(centerLeft|centerRight)');

          for (final f in _dartFilesUnder(featuresDir)) {
            if (f.path.endsWith('.g.dart') ||
                f.path.endsWith('.freezed.dart') ||
                f.path.endsWith('.mocks.dart')) {
              continue;
            }
            final src = f.readAsStringSync();
            if (pattern.hasMatch(src)) {
              var lineNo = 0;
              for (final line in src.split('\n')) {
                lineNo++;
                if (pattern.hasMatch(line)) {
                  offenders.add('${f.path}:$lineNo — $line');
                }
              }
            }
          }

          expect(
            offenders,
            isEmpty,
            reason:
                'AC2: Alignment.centerLeft/centerRight flip in RTL. '
                'Use AlignmentDirectional.centerStart/centerEnd.\n'
                '${offenders.join('\n')}',
          );
        },
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC3 — no TextAlign.left or TextAlign.right in lib/features/
  //        (must use TextAlign.start / TextAlign.end)
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 26.31 AC3 — TextAlign.left/right replaced',
    tags: ['story_26_31'],
    () {
      test('no TextAlign.left or TextAlign.right in lib/features/', () {
        final offenders = <String>[];
        final pattern = RegExp(r'TextAlign\.(left|right)');

        for (final f in _dartFilesUnder(featuresDir)) {
          if (f.path.endsWith('.g.dart') ||
              f.path.endsWith('.freezed.dart') ||
              f.path.endsWith('.mocks.dart')) {
            continue;
          }
          final src = f.readAsStringSync();
          if (pattern.hasMatch(src)) {
            var lineNo = 0;
            for (final line in src.split('\n')) {
              lineNo++;
              if (pattern.hasMatch(line)) {
                offenders.add('${f.path}:$lineNo — $line');
              }
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'AC3: TextAlign.left/right are LTR-specific. '
              'Use TextAlign.start/end instead.\n'
              '${offenders.join('\n')}',
        );
      });
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // AC4 — positive guard: directional variants appear in migrated key files
  // ────────────────────────────────────────────────────────────────────────────

  group(
    'Story 26.31 AC4 — directional replacements confirmed in key files',
    tags: ['story_26_31'],
    () {
      String readFeatureFile(String relPath) =>
          readLibSource('features/$relPath');

      test('daily_task_card.dart uses AlignmentDirectional.centerEnd', () {
        final src = readFeatureFile(
          'scheduler/presentation/widgets/daily_task_card.dart',
        );
        expect(
          src,
          contains('AlignmentDirectional.centerEnd'),
          reason:
              'AC4: the dismiss background Container must use '
              'AlignmentDirectional.centerEnd instead of Alignment.centerRight.',
        );
      });

      test(
        'account_picker_screen.dart uses EdgeInsetsDirectional.only(end: 20)',
        () {
          final src = readFeatureFile(
            'account/presentation/screens/account_picker_screen.dart',
          );
          expect(
            src,
            contains('EdgeInsetsDirectional.only(end: 20)'),
            reason:
                'AC4: the dismissible background padding must use '
                'EdgeInsetsDirectional.only(end: 20).',
          );
        },
      );

      // add_track_flow.dart (checked by a former AC4 case here) was deleted
      // by DNI-353 (26.10), along with the old flattened directory it lived
      // under (removed by commit e365a4c8; the canonical location for this
      // feature is features/tracks/setup/). That case's own
      // "add_track_flow_screen.dart already uses AlignmentDirectional"
      // comment does not hold up: the screen file contains no
      // Alignment-related code at all today. AC1-AC3's repo-wide regex
      // sweep above already covers add_track_flow_screen.dart across all of
      // lib/features/, so no positive guard is needed for it here
      // (AUD-t-story-acceptance-35).

      test(
        'content_item_tile.dart uses TextAlign.start instead of TextAlign.left/right',
        () {
          final src = readFeatureFile(
            'content_browsing/presentation/widgets/content_item_tile.dart',
          );
          expect(
            src,
            contains('TextAlign.start'),
            reason:
                'AC4: content_item_tile.dart must use TextAlign.start for '
                'RTL-safe text alignment.',
          );
        },
      );
    },
  );
}
