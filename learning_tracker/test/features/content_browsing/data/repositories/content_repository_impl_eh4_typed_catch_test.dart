/// Regression test for AUD-content_browsing-09 (EH-4) —
/// `ContentRepositoryImpl.getContentForCurriculum`'s asset-load/parse
/// `catch` clause.
///
/// Before the fix, `catch (e)` at content_repository_impl.dart:87 caught
/// EVERYTHING — including a `TypeError` raised by `_parseAndCache`'s bad
/// casts on schema-mismatched asset JSON — and folded it into a generic
/// `ContentLoadException`, hiding the real defect (a bad cast, i.e. a
/// content-authoring/schema bug) behind an ordinary "content failed to
/// load" exception indistinguishable from a genuinely missing/corrupt
/// asset file.
///
/// After the fix (`on Exception catch (e)`), the `TypeError` is NOT an
/// `Exception` so it is no longer caught here — it propagates raw, letting
/// it reach the zone's uncaught-error handler (or a test's `throwsA`)
/// instead of being silently repackaged. The same is true of a genuinely
/// missing asset file (`FlutterError`, also an `Error` subtype) — see the
/// second test below and the updated interface doc comment on
/// `ContentRepository.getContentForCurriculum`.
///
/// Mocks the `flutter/assets` platform channel directly (the same
/// technique `content_repository_test.dart` relies on implicitly via
/// `TestWidgetsFlutterBinding.ensureInitialized()`) so malformed/missing
/// asset scenarios can be injected without real corrupt/missing asset
/// files on disk.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  /// Registers a `flutter/assets` mock that responds to exactly [assetKey]
  /// with [jsonString] and returns null (asset not found) for every other
  /// key.
  void mockAssetWith({required String assetKey, required String jsonString}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final requestedKey = utf8.decode(message!.buffer.asUint8List());
          if (requestedKey != assetKey) return null;
          final bytes = Uint8List.fromList(utf8.encode(jsonString));
          return ByteData.view(bytes.buffer);
        });
  }

  test('AUD-content_browsing-09 (EH-4): a TypeError from a schema-mismatched '
      'asset (bad cast in _parseAndCache) propagates raw — it is NOT '
      'swallowed into a generic ContentLoadException', () async {
    // 'totalItems' is a String, not an int — configJson['totalItems'] as
    // int throws a raw TypeError deep inside _parseAndCache, well past
    // the point jsonDecode's own FormatException would have already
    // fired for genuinely malformed (unparsable) JSON.
    mockAssetWith(
      assetKey: 'assets/content/hierarchy/mishnayos.json',
      jsonString: jsonEncode({
        'hierarchyConfig': {
          'curriculumId': 'mishnayos',
          'levelLabels': ['Seder', 'Masechta'],
          'totalItems': 'not-a-number',
        },
        'items': <Map<String, dynamic>>[],
      }),
    );

    final repo = ContentRepositoryImpl();

    // RED (pre-fix, bare `catch (e)`): this throws ContentLoadException,
    // wrapping the TypeError and hiding it — `throwsA(isA<TypeError>())`
    // fails with "Expected: throws an instance of TypeError / Actual:
    // <Closure>: threw ContentLoadException:...".
    // GREEN (post-fix, `on Exception catch (e)`): the TypeError is not
    // an Exception, escapes the catch clause, and propagates raw.
    await expectLater(
      () => repo.getContentForCurriculum(CurriculumId.mishnayos),
      throwsA(isA<TypeError>()),
    );
  });

  test('AUD-content_browsing-09 (EH-4): a missing asset file now propagates '
      'as a raw platform error instead of being downgraded to '
      'ContentLoadException', () async {
    // A DIFFERENT curriculum/asset key than the first test — rootBundle
    // is a CachingAssetBundle that memoises loadString() by key, so
    // reusing 'mishnayos' here would silently replay the first test's
    // cached (malformed) string instead of exercising this scenario.
    // No mock is registered for this key, so rootBundle.loadString
    // surfaces the platform's own "Unable to load asset" FlutterError —
    // an Error subtype, not an Exception.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'flutter/assets',
          (ByteData? message) async => null,
        );

    final repo = ContentRepositoryImpl();

    // RED (pre-fix, bare `catch (e)`): the bare catch caught this
    // FlutterError too and wrapped it as ContentLoadException — matching
    // the OLD interface doc comment ("Throws ContentLoadException if the
    // asset file is missing or malformed").
    // GREEN (post-fix, `on Exception catch (e)`): FlutterError is an
    // Error, not an Exception, so it now propagates raw. A missing asset
    // for a CurriculumId this method is called with indicates a
    // content-bundling defect, not an ordinary recoverable failure — see
    // the updated ContentRepository.getContentForCurriculum doc comment.
    await expectLater(
      () => repo.getContentForCurriculum(CurriculumId.bavli),
      throwsA(isA<FlutterError>()),
    );
  });

  test('sanity: genuinely unparsable JSON (a FormatException, an ordinary '
      'Exception) is still wrapped as ContentLoadException — unchanged by '
      'the EH-4 narrowing', () async {
    mockAssetWith(
      assetKey: 'assets/content/hierarchy/chumash.json',
      jsonString: '{not valid json',
    );

    final repo = ContentRepositoryImpl();

    await expectLater(
      () => repo.getContentForCurriculum(CurriculumId.chumash),
      throwsA(isA<ContentLoadException>()),
    );
  });
}
