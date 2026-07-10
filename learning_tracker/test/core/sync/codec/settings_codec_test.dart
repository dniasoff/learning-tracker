/// AUD-core-sync-38 checker: [SettingsCodec.encode] has zero production
/// call sites (`grep -rn 'SettingsCodec()' lib/ test/` finds only the
/// decode-side caller in `settings_merger.dart`) — unlike every sibling
/// codec, where `encode()` is the live push path. A symmetric but
/// unreachable `encode()` looks load-bearing to a reader and invites either
/// a false assumption that it's exercised, or silent drift from the real
/// settings push shape with nothing to notice if it ever changes.
///
/// The interface contract (`EntityCodec<T>.encode`) means the method can't
/// be literally deleted, so the remediation is a throwing stub that
/// documents the decode-only status — this test is the AC-named checker
/// for that: it fails red while `encode()` still silently returns a
/// working map, and passes once `encode()` is converted to a documented
/// throwing stub.
@Tags(['unit', 'sync'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';

const _codec = SettingsCodec();

void main() {
  group('SettingsCodec.encode — decode-only status (AUD-core-sync-38)', () {
    test(
      'encode() throws to document that settings is currently pull/decode-only',
      () {
        expect(
          () => _codec.encode(const SettingsRow(curriculumId: 'bavli')),
          throwsUnsupportedError,
          reason:
              'SettingsCodec.encode() has zero production call sites — '
              'nothing in lib/ builds a settings push payload. A working '
              'but unreachable encode() invites either a false assumption '
              "that it's exercised, or silent drift from the real settings "
              'push shape with nothing to notice if it ever changes. It '
              'must throw so any future caller discovers the decode-only '
              'contract immediately rather than shipping a payload nobody '
              'validates.',
        );
      },
    );

    test('grep: SettingsCodec().encode / SettingsCodec.encode has zero call '
        'sites in lib/ outside the codec\'s own definition', () {
      final libDir = Directory('lib');
      expect(
        libDir.existsSync(),
        isTrue,
        reason:
            'Expected lib/ at the flutter package root. Run this test '
            'from learning_tracker/ (working dir = package root).',
      );

      final callSitePattern = RegExp(
        r'SettingsCodec\(\)\.encode|SettingsCodec\.encode',
      );
      final offendingFiles = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The codec's own class definition names EntityCodec's `encode`
        // override — that's the declaration, not a call site.
        if (entity.path.endsWith('settings_codec.dart')) continue;

        final content = entity.readAsStringSync();
        if (callSitePattern.hasMatch(content)) {
          offendingFiles.add(entity.path);
        }
      }

      expect(
        offendingFiles,
        isEmpty,
        reason:
            'If this fails, SettingsCodec.encode() has gained a real '
            'production call site — great, but then encode() must go '
            'back to being a working serializer (not a throwing stub) '
            'and this AUD-core-sync-38 checker test should be updated / '
            'removed to match. Offending files: $offendingFiles',
      );
    });
  });
}
