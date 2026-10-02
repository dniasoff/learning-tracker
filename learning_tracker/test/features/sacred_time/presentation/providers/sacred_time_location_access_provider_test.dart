// SacredTimeLocationAccess: the one-shot pass an in-app flow that already
// verified the Parent PIN hands the city picker's route guard (DNI-481 AC-3).
@Tags(['sacred_time'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_time_location_access_provider.dart';

void main() {
  late DateTime now;
  late SacredTimeLocationAccess access;

  setUp(() {
    now = DateTime.utc(2026, 10, 2, 12);
    access = SacredTimeLocationAccess(now: () => now);
  });

  test('no pass is pending at first', () {
    expect(access.consume('p1'), isFalse);
  });

  test('a pass opens once, for its own profile only', () {
    access.grant('p1');
    expect(access.consume('p1'), isTrue);
    expect(access.consume('p1'), isFalse);
  });

  test('a pass for another profile is refused and used up', () {
    access.grant('p1');
    expect(access.consume('p2'), isFalse);
    expect(access.consume('p1'), isFalse);
  });

  test('a null holder never passes and uses the pass up', () {
    access.grant('p1');
    expect(access.consume(null), isFalse);
    expect(access.consume('p1'), isFalse);
  });

  test('a later grant replaces the earlier pass', () {
    access
      ..grant('p1')
      ..grant('p2');
    expect(access.consume('p1'), isFalse);
    access.grant('p2');
    expect(access.consume('p2'), isTrue);
  });

  test('a pass lapses after the ttl', () {
    access.grant('p1');
    now = now.add(SacredTimeLocationAccess.ttl);
    expect(access.consume('p1'), isTrue);

    access.grant('p1');
    now = now.add(SacredTimeLocationAccess.ttl + const Duration(seconds: 1));
    expect(access.consume('p1'), isFalse);
  });

  test('a pass from the future (clock moved back) is refused', () {
    access.grant('p1');
    now = now.subtract(const Duration(seconds: 1));
    expect(access.consume('p1'), isFalse);
  });

  test('the provider serves one holder for the app', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sacredTimeLocationAccessProvider).grant('p1');
    expect(
      container.read(sacredTimeLocationAccessProvider).consume('p1'),
      isTrue,
    );
  });
}
