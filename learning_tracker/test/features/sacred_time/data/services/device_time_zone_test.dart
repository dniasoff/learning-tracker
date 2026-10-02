// Mirror test for `lib/features/sacred_time/data/services/device_time_zone.dart`
// (DNI-481).
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/data/services/device_time_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the provider defaults to the platform reader', () {
    final container = ProviderContainer.test();
    expect(container.read(deviceTimeZoneReaderProvider), readPlatformTimeZone);
  });

  test('an unreadable platform zone reads as null, never a fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), (
          call,
        ) async {
          throw PlatformException(code: 'unavailable');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_timezone'),
            null,
          ),
    );
    expect(await readPlatformTimeZone(), isNull);
  });
}
