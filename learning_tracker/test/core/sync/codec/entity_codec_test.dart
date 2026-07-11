/// Unit tests for lib/core/sync/codec/entity_codec.dart: the abstract
/// [EntityCodec] contract.
///
/// Every concrete codec (BookmarkCodec, GoalCodec, ...) has its own
/// mirrored test exercising real decode()/encode() behaviour; this file
/// covers only the abstract contract shape declared in entity_codec.dart
/// itself.
///
/// AG-5 (AUD-app-05): new file — no prior mirrored or unmirrored test
/// existed for this file.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';

class _Model {
  const _Model(this.id);
  final String id;
}

/// Minimal concrete [EntityCodec] mirroring the class doc's own usage
/// example, used only to prove the abstract contract is implementable.
class _MinimalCodec extends EntityCodec<_Model> {
  const _MinimalCodec();

  @override
  String get kind => 'minimal';

  @override
  _Model? decode(Map<String, dynamic> raw) {
    final id = raw['id'] as String?;
    if (id == null) return null;
    return _Model(id);
  }

  @override
  Map<String, dynamic> encode(_Model model) => {'id': model.id};
}

void main() {
  group('EntityCodec contract', () {
    const codec = _MinimalCodec();

    test('a concrete implementation exposes its kind', () {
      expect(codec.kind, 'minimal');
    });

    test('encode → decode round-trips through a concrete implementation', () {
      final decoded = codec.decode(codec.encode(const _Model('abc')));
      expect(decoded, isNotNull);
      expect(decoded!.id, 'abc');
    });

    test('decode() returns null when a required field is missing', () {
      expect(codec.decode(const {}), isNull);
    });

    test('encode() returns a JSON-safe Map<String, dynamic>', () {
      final payload = codec.encode(const _Model('xyz'));
      expect(payload, isA<Map<String, dynamic>>());
      expect(payload['id'], 'xyz');
    });
  });
}
