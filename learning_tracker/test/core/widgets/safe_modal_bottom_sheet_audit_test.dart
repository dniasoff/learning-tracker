import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application modal sheets use the shared safe-area helper', () async {
    final violations = <String>[];
    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('safe_modal_bottom_sheet.dart')) continue;

      final source = await entity.readAsString();
      if (RegExp(r'\bshowModalBottomSheet(?:<[^>]+>)?\s*\(').hasMatch(source)) {
        violations.add(entity.path);
      }
    }

    expect(violations, isEmpty, reason: 'Use showSafeModalBottomSheet.');
  });
}
