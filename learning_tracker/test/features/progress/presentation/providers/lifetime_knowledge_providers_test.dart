import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

void main() {
  group('lifetimeDataProvider', () {
    test('is a family provider keyed by profileId and curriculumId', () {
      // Verify provider identity: calling with different args gives different
      // provider instances.
      const arg1 = (profileId: 1, curriculumId: CurriculumId.mishnayos);
      const arg2 = (profileId: 1, curriculumId: CurriculumId.bavli);
      const arg3 = (profileId: 2, curriculumId: CurriculumId.mishnayos);

      final p1 = lifetimeDataProvider(arg1);
      final p2 = lifetimeDataProvider(arg2);
      final p3 = lifetimeDataProvider(arg3);

      // Different curriculum → different provider.
      expect(p1, isNot(equals(p2)));
      // Different profileId → different provider.
      expect(p1, isNot(equals(p3)));
      // Same args → same provider.
      expect(lifetimeDataProvider(arg1), equals(p1));
    });

    test('all nine CurriculumId values can be used as family args', () {
      // Smoke-test that every curriculum resolves to a distinct provider so
      // the family covers the full set without runtime errors.
      final providers = CurriculumId.values
          .map((c) => lifetimeDataProvider((profileId: 1, curriculumId: c)))
          .toList();

      expect(providers.length, CurriculumId.values.length);
      // All provider instances must be distinct (they are auto-dispose family).
      final unique = providers.toSet();
      expect(unique.length, providers.length);
    });
  });

  group('lifetimeSummariesProvider', () {
    test('is a family provider keyed by profileId', () {
      final p1 = lifetimeSummariesProvider(1);
      final p2 = lifetimeSummariesProvider(2);

      expect(p1, isNot(equals(p2)));
      expect(lifetimeSummariesProvider(1), equals(p1));
    });

    test(
      'overrides return expected summaries without hitting database',
      () async {
        const fakeSummary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.mishnayos,
          learnedLeafCount: 10,
          totalLeafCount: 100,
          percentage: 0.1,
          tree: [],
        );

        final container = ProviderContainer(
          overrides: [
            lifetimeSummariesProvider(
              42,
            ).overrideWith((ref) => Future.value([fakeSummary])),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          lifetimeSummariesProvider(42).future,
        );

        expect(result, hasLength(1));
        expect(result.first.curriculumId, CurriculumId.mishnayos);
        expect(result.first.learnedLeafCount, 10);
        expect(result.first.percentage, 0.1);
      },
    );
  });

  group('lifetimeDataProvider override', () {
    test('single-curriculum override returns only that curriculum', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeDataProvider((
            profileId: 1,
            curriculumId: CurriculumId.chumash,
          )).overrideWith(
            (ref) => Future.value(
              const CurriculumLifetimeSummary(
                curriculumId: CurriculumId.chumash,
                learnedLeafCount: 5,
                totalLeafCount: 50,
                percentage: 0.1,
                tree: [],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        lifetimeDataProvider((
          profileId: 1,
          curriculumId: CurriculumId.chumash,
        )).future,
      );

      expect(result, isNotNull);
      expect(result!.curriculumId, CurriculumId.chumash);
      expect(result.learnedLeafCount, 5);
    });

    test('null result represents missing curriculum asset', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeDataProvider((
            profileId: 1,
            curriculumId: CurriculumId.yerushalmi,
          )).overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        lifetimeDataProvider((
          profileId: 1,
          curriculumId: CurriculumId.yerushalmi,
        )).future,
      );

      expect(result, isNull);
    });
  });

  group('CurriculumLifetimeSummary', () {
    test('percentage clamping semantics', () {
      const summary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mussar,
        learnedLeafCount: 0,
        totalLeafCount: 10,
        percentage: 0.0,
        tree: [],
      );

      expect(summary.percentage, 0.0);
      expect(summary.learnedLeafCount, 0);
      expect(summary.totalLeafCount, 10);
    });

    test('full completion percentage', () {
      const summary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mishnehTorah,
        learnedLeafCount: 200,
        totalLeafCount: 200,
        percentage: 1.0,
        tree: [],
      );

      expect(summary.percentage, 1.0);
    });
  });

  group('LifetimeTotals', () {
    test('percentage returns ratio', () {
      const totals = LifetimeTotals(
        learnedSections: 25,
        totalSections: 100,
        totalCurricula: 9,
      );

      expect(totals.percentage, closeTo(0.25, 0.001));
    });

    test('percentage is 0 when totalSections is 0', () {
      const totals = LifetimeTotals(
        learnedSections: 0,
        totalSections: 0,
        totalCurricula: 9,
      );

      expect(totals.percentage, 0.0);
    });
  });

  group('globalLifetimeCurriculaProvider alias', () {
    test('is the same provider object as lifetimeSummariesProvider', () {
      // The deprecated alias must forward to the same underlying family.
      // ignore: deprecated_member_use
      final aliasP = globalLifetimeCurriculaProvider(1);
      final newP = lifetimeSummariesProvider(1);

      expect(aliasP, equals(newP));
    });
  });
}
