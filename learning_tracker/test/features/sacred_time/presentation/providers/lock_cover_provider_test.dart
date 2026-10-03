// Mirror test for
// `lib/features/sacred_time/presentation/providers/lock_cover_provider.dart`
// (DNI-481 AC-1/AC-2): the registry of engaged Sacred Time lock covers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/lock_cover_provider.dart';

void main() {
  test('engaged while any cover is engaged, released when all are', () {
    final container = ProviderContainer.test();
    final covers = container.read(lockCoversProvider.notifier);
    final device = Object();
    final tutored = Object();

    expect(container.read(lockCoverEngagedProvider), isFalse);
    covers
      ..engage(device)
      ..engage(tutored)
      ..engage(device);
    expect(container.read(lockCoversProvider), hasLength(2));
    expect(container.read(lockCoverEngagedProvider), isTrue);

    covers.release(device);
    expect(container.read(lockCoverEngagedProvider), isTrue);
    covers
      ..release(tutored)
      ..release(tutored);
    expect(container.read(lockCoverEngagedProvider), isFalse);
  });

  test('a cover released after its container is gone is a no-op', () {
    final container = ProviderContainer();
    final covers = container.read(lockCoversProvider.notifier);
    container.dispose();
    expect(() => covers.release(Object()), returnsNormally);
  });
}
