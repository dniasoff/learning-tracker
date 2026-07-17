/// AUD-progress-15 regression guard — RecentActivityWindow must not
/// hand-write operator==/hashCode.
///
/// docs/coding-standards.md: "Domain/state models are immutable @freezed
/// classes (generated ==/copyWith); never hand-write ==/hashCode for data
/// classes — hand-rolled equality drifts from the fields and silently
/// breaks rebuild-skipping."
///
/// RecentActivityWindow is the [FutureProvider.family] key for the four
/// Recent Activity data feeds. Before this fix it hand-wrote operator==/
/// hashCode; a future field added to the class but forgotten in a
/// hand-rolled operator== would silently under-compare, causing stale
/// FutureProvider.family cache hits. A pure equality-*behavior* test would
/// stay green even against the old hand-rolled implementation (it was
/// correct for its current 3 fields), so this test also greps the source
/// directly — that's the part that actually red-lines on the violation
/// this finding names, and stays red as long as anyone reintroduces a
/// hand-written override.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/presentation/providers/recent_activity_providers.dart';

void main() {
  group('AUD-progress-15: RecentActivityWindow equality', () {
    test('recent_activity_providers.dart source has no hand-written '
        'operator==/hashCode on RecentActivityWindow', () {
      final source = File(
        'lib/features/progress/presentation/providers/recent_activity_providers.dart',
      ).readAsStringSync();

      expect(
        source.contains('operator =='),
        isFalse,
        reason:
            'RecentActivityWindow must rely on @freezed-generated '
            'equality, not a hand-written operator== (AUD-progress-15).',
      );
      expect(
        source.contains('get hashCode'),
        isFalse,
        reason:
            'RecentActivityWindow must rely on @freezed-generated '
            'hashCode, not a hand-written override (AUD-progress-15).',
      );
      expect(
        source.contains('@freezed'),
        isTrue,
        reason: 'RecentActivityWindow must be declared @freezed.',
      );
    });

    test('two windows with identical fields are == and share a hashCode', () {
      final a = RecentActivityWindow(
        startDate: DateTime.utc(2026, 6, 1),
        endDate: DateTime.utc(2026, 6, 7),
        curriculumId: 'bavli',
      );
      final b = RecentActivityWindow(
        startDate: DateTime.utc(2026, 6, 1),
        endDate: DateTime.utc(2026, 6, 7),
        curriculumId: 'bavli',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('windows differing in any single field are not ==', () {
      final base = RecentActivityWindow(
        startDate: DateTime.utc(2026, 6, 1),
        endDate: DateTime.utc(2026, 6, 7),
        curriculumId: 'bavli',
      );

      final differentStart = RecentActivityWindow(
        startDate: DateTime.utc(2026, 6, 2),
        endDate: base.endDate,
        curriculumId: base.curriculumId,
      );
      final differentEnd = RecentActivityWindow(
        startDate: base.startDate,
        endDate: DateTime.utc(2026, 6, 8),
        curriculumId: base.curriculumId,
      );
      final differentCurriculum = RecentActivityWindow(
        startDate: base.startDate,
        endDate: base.endDate,
        curriculumId: 'mishnah',
      );
      final nullCurriculum = RecentActivityWindow(
        startDate: base.startDate,
        endDate: base.endDate,
      );

      expect(base, isNot(equals(differentStart)));
      expect(base, isNot(equals(differentEnd)));
      expect(base, isNot(equals(differentCurriculum)));
      expect(base, isNot(equals(nullCurriculum)));
    });
  });
}
