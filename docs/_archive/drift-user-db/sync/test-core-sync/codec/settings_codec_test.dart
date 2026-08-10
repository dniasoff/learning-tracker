/// Unit tests for [SettingsCodec]: the decode-only status checker
/// (AUD-core-sync-38), decode()'s required curriculum_id null-guard, and
/// the nested `stages` array (W3.32 combined-document shape, delegating to
/// [StageDefinitionCodec]).
///
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
///
/// AG-5 (AUD-app-05): decode()-side coverage below is the mirrored test
/// this checker requires for lib/core/sync/codec/settings_codec.dart —
/// built on raw maps rather than via `encode()`, since `encode()` is
/// decode-only (see above). SettingsMerger's own tests likewise use raw
/// maps built by hand rather than this codec's encode().
@Tags(['unit', 'sync'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

const _codec = SettingsCodec();

void main() {
  group('SettingsCodec — kind', () {
    test('kind is "settings"', () {
      expect(_codec.kind, EntityKind.settings);
    });
  });

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

  group('SettingsCodec — decode returns null for malformed inputs', () {
    test('missing curriculum_id', () {
      expect(_codec.decode({'track_id': 1}), isNull);
    });

    test('empty map', () {
      expect(_codec.decode(const {}), isNull);
    });
  });

  group('SettingsCodec — nested stage definitions', () {
    test('decodes a nested stages array via StageDefinitionCodec', () {
      final decoded = _codec.decode({
        'curriculum_id': 'bavli',
        'stages': [
          {
            'curriculum_id': 'bavli',
            'track_id': 1,
            'stage_order': 0,
            'stage_name': 'Stage 1',
            'schedule': '{"type":"delay","delay_days":7}',
            'is_default': true,
          },
        ],
      });
      expect(decoded, isNotNull);
      expect(decoded!.stages, hasLength(1));
      expect(decoded.stages.single.stageName, 'Stage 1');
    });

    test(
      'a malformed nested stage entry is dropped, not the whole document',
      () {
        final decoded = _codec.decode({
          'curriculum_id': 'bavli',
          'stages': [
            {'stage_name': 'missing required fields'},
          ],
        });
        expect(decoded, isNotNull);
        expect(decoded!.stages, isEmpty);
      },
    );

    test('missing stages key decodes to an empty list', () {
      final decoded = _codec.decode({'curriculum_id': 'bavli'});
      expect(decoded?.stages, isEmpty);
    });
  });
}
