// Regression test for AUD-t-cross-03 (TQ-5): the Material fonts directory
// used by golden tests must be resolved portably — never a hardcoded path
// tied to one developer's home directory / FVM install.
import 'package:flutter_test/flutter_test.dart';

import 'golden_font_loader.dart';

void main() {
  group('materialFontsDir', () {
    test('resolves from FLUTTER_ROOT when present (portable across '
        'machines/CI, no hardcoded developer path)', () {
      final dir = materialFontsDir(
        environment: {'FLUTTER_ROOT': '/opt/flutter-ci'},
      );

      expect(dir, '/opt/flutter-ci/bin/cache/artifacts/material_fonts');
    });

    test('never bakes in this-machine-specific path fragments', () {
      final dir = materialFontsDir(
        environment: {'FLUTTER_ROOT': '/opt/flutter-ci'},
      );

      // The historical defect (AUD-t-cross-03): a literal
      // '/home/daniel/fvm/versions/stable/...' path that only existed on
      // one developer's laptop. Assert neither fragment can leak in via a
      // fallback default.
      expect(dir, isNot(contains('/home/daniel')));
      expect(dir, isNot(contains('fvm')));
    });

    test('falls back to deriving the SDK root from the test-runner executable '
        'path when FLUTTER_ROOT is unset', () {
      final dir = materialFontsDir(
        environment: const {},
        resolvedExecutable:
            '/opt/sdk/bin/cache/artifacts/engine/linux-x64/flutter_tester',
      );

      expect(dir, '/opt/sdk/bin/cache/artifacts/material_fonts');
    });

    test('returns null (never a hardcoded fallback) when neither FLUTTER_ROOT '
        'nor a resolvable executable path is available', () {
      final dir = materialFontsDir(
        environment: const {},
        resolvedExecutable: '/usr/bin/dart',
      );

      expect(dir, isNull);
    });

    test('empty-string FLUTTER_ROOT is treated as unset', () {
      final dir = materialFontsDir(
        environment: const {'FLUTTER_ROOT': ''},
        resolvedExecutable:
            '/opt/sdk/bin/cache/artifacts/engine/linux-x64/flutter_tester',
      );

      expect(dir, '/opt/sdk/bin/cache/artifacts/material_fonts');
    });
  });
}
