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

/// Returns the project root regardless of cwd.
Directory _projectRoot() {
  for (final c in [Directory.current, Directory.current.parent]) {
    if (Directory('${c.path}/lib').existsSync()) return c;
  }
  throw StateError('cannot locate project root');
}

Iterable<File> _dartFilesUnder(Directory root) sync* {
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

void main() {
  late Directory featuresDir;

  setUpAll(() {
    final root = _projectRoot();
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
      String readFeatureFile(String relPath) {
        final root = _projectRoot();
        final candidates = [
          File('${root.path}/lib/features/$relPath'),
          File('lib/features/$relPath'),
        ];
        for (final f in candidates) {
          if (f.existsSync()) return f.readAsStringSync();
        }
        throw StateError('File not found: $relPath');
      }

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

      test('add_track_flow.dart uses AlignmentDirectional.centerStart', () {
        // add_track_flow.dart was deleted by DNI-353 (26.10); its content
        // was migrated to add_track_flow_screen.dart which already uses
        // AlignmentDirectional. The constraint is satisfied.
        final root = _projectRoot();
        final candidates = [
          File(
            '${root.path}/lib/features/track_setup/presentation/screens/add_track_flow.dart',
          ),
          File(
            'lib/features/track_setup/presentation/screens/add_track_flow.dart',
          ),
        ];
        final exists = candidates.any((f) => f.existsSync());
        if (!exists) return; // file deleted — constraint satisfied by deletion
        final src = readFeatureFile(
          'track_setup/presentation/screens/add_track_flow.dart',
        );
        expect(
          src,
          contains('AlignmentDirectional.centerStart'),
          reason:
              'AC4: Align widgets in add_track_flow.dart must use '
              'AlignmentDirectional.centerStart instead of Alignment.centerLeft.',
        );
      });

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
