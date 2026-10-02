// Mirror test for `lib/domain/learner_state/lock_windows.dart`
// (C0, DNI-524 AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/c0_stub_matcher.dart';

void main() {
  final start = DateTime.utc(2026, 9, 4, 16);
  final end = DateTime.utc(2026, 9, 5, 17);
  const us = Duration(microseconds: 1);

  test('UtcInterval.contains is closed at both ends', () {
    final i = UtcInterval(start, end);
    expect(i.contains(start), isTrue);
    expect(i.contains(end), isTrue);
    expect(i.contains(start.add(const Duration(hours: 3))), isTrue);
    expect(i.contains(start.subtract(us)), isFalse);
    expect(i.contains(end.add(us)), isFalse);
  });

  test('LockWindow is a UtcInterval with the same semantics', () {
    final lock = LockWindow(start, end);
    expect(lock, isA<UtcInterval>());
    expect(lock.contains(start), isTrue);
    expect(lock.contains(end.add(us)), isFalse);
  });

  test('value equality distinguishes a lock from a plain interval', () {
    expect(LockWindow(start, end), LockWindow(start, end));
    expect(LockWindow(start, end).hashCode, LockWindow(start, end).hashCode);
    expect(LockWindow(start, end), isNot(UtcInterval(start, end)));
    expect(UtcInterval(start, end), UtcInterval(start, end));
  });

  group('rule functions are C0 stubs owned by DNI-466', () {
    final history = c0SettingsHistory();
    final lock = LockWindow(start, end);

    test('lockWindows', () {
      expect(
        () => lockWindows(history, start, end),
        throwsC0Stub('DNI-466', 'lockWindows'),
      );
    });

    test('lockedDays', () {
      expect(
        () => lockedDays(lock, history),
        throwsC0Stub('DNI-466', 'lockedDays'),
      );
    });

    test('catchUpWindow', () {
      expect(
        () => catchUpWindow(lock, history),
        throwsC0Stub('DNI-466', 'catchUpWindow'),
      );
    });
  });
}
