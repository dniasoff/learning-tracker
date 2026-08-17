import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  // DNI-328 flipped the Hebrew-terms default to false (English transliteration).
  // These tests assert on Hebrew strings so seed the per-profile preference to
  // true before each test.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
  });

  // [router] is only needed by the navigation test — it wraps [home] in a
  // StackRouterScope so `context.router` resolves to the mocked StackRouter
  // instead of throwing for want of a real AutoRouter ancestor.
  Widget createTestWidget({
    required ContentRepository repository,
    _MockStackRouter? router,
    bool useHebrewTerms = true,
    TransliterationVariant transliterationVariant =
        TransliterationVariant.ashkenazi,
  }) {
    final home = router == null
        ? const CurriculumListScreen()
        : StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const CurriculumListScreen(),
          );
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(repository),
        // Override the completion percentage provider to avoid DB dependency
        dashboardCompletionPercentageProvider.overrideWith(
          (ref, curriculum) async => 0.0,
        ),
        // Preferences are now keyed by the selected profile's ULID; seed the
        // providers directly instead of relying on the retired p0 keys.
        useHebrewTermsProvider.overrideWithValue(useHebrewTerms),
        currentTransliterationVariantProvider.overrideWithValue(
          transliterationVariant,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  group('CurriculumListScreen', () {
    testWidgets('displays all curricula', (tester) async {
      final mockRepo = MockContentRepository();

      // Mock all curricula returning empty lists (just need the calls to succeed)
      for (final curriculum in CurriculumId.values) {
        when(
          () => mockRepo.getContentForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Should show curriculum Hebrew names — verify first few visible
      expect(find.text('משניות'), findsWidgets);
      expect(find.text('תלמוד בבלי'), findsWidgets);
    });

    testWidgets('displays item counts for each curriculum', (tester) async {
      final mockRepo = MockContentRepository();

      // Mock Mishnayos with 10 leaf items
      when(
        () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => List.generate(
          10,
          (i) => ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Level $i',
            displayNameHe: 'Hebrew $i',
            displayNameEn: 'English $i',
            sefariaRef: 'Ref $i',
            sortOrder: i,
            isLeaf: true,
          ),
        ),
      );

      // Mock others with empty lists
      for (final curriculum in CurriculumId.values) {
        if (curriculum != CurriculumId.mishnayos) {
          when(
            () => mockRepo.getContentForCurriculum(curriculum),
          ).thenAnswer((_) async => []);
        }
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Should show count for Mishnayos
      expect(find.textContaining('10'), findsWidgets);
    });

    testWidgets(
      'count labels honor Sephardi transliteration variant in English mode',
      (tester) async {
        // English mode (so the transliteration variant is consulted) +
        // Sephardi nusach. Mishnayos count labels must read "Masekhtot"
        // (container) and "Mishnayot" (unit), NOT the Ashkenazi
        // "Masechtos"/"Mishnayos".
        SharedPreferences.setMockInitialValues(<String, Object>{
          'hebrew_terms_script_p0': false,
          'transliteration_variant_p0': 'sephardi',
        });

        final mockRepo = MockContentRepository();

        // Mishnayos with one non-leaf container + one leaf item so both
        // containerCount (>0) and leafCount (>0) render their labels.
        when(
          () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => const [
            ContentItem(
              curriculumId: 'mishnayos',
              level1: 'Zeraim',
              displayNameHe: 'מסכת ברכות',
              displayNameEn: 'Berachos',
              sefariaRef: 'Mishnah Berakhot',
              sortOrder: 0,
              isLeaf: false,
            ),
            ContentItem(
              curriculumId: 'mishnayos',
              level1: 'Zeraim',
              level2: 'Berachos',
              displayNameHe: 'משנה א',
              displayNameEn: 'Mishnah 1',
              sefariaRef: 'Mishnah Berakhot 1:1',
              sortOrder: 1,
              isLeaf: true,
            ),
          ],
        );

        for (final curriculum in CurriculumId.values) {
          if (curriculum != CurriculumId.mishnayos) {
            when(
              () => mockRepo.getContentForCurriculum(curriculum),
            ).thenAnswer((_) async => []);
          }
        }

        await tester.pumpWidget(
          createTestWidget(
            repository: mockRepo,
            useHebrewTerms: false,
            transliterationVariant: TransliterationVariant.sephardi,
          ),
        );
        await tester.pumpAndSettle();

        // Count labels carry the Sephardi forms ("1 Masekhtot" container
        // count, "1 Mishnayot" unit count). Match the count-prefixed strings
        // so the assertion targets the labels under test and not the
        // curriculum card title ("Mishnayos").
        expect(find.textContaining('1 Masekhtot'), findsWidgets);
        expect(find.textContaining('1 Mishnayot'), findsWidgets);
        // Ashkenazi count labels must NOT leak through.
        expect(find.textContaining('1 Masechtos'), findsNothing);
        expect(find.textContaining('1 Mishnayos'), findsNothing);
      },
    );

    testWidgets('navigates to content hierarchy when curriculum tapped', (
      tester,
    ) async {
      final mockRepo = MockContentRepository();
      final router = _MockStackRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);

      for (final curriculum in CurriculumId.values) {
        when(
          () => mockRepo.getContentForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
      }

      await tester.pumpWidget(
        createTestWidget(repository: mockRepo, router: router),
      );
      await tester.pumpAndSettle();

      // Tap on Mishnayos curriculum
      await tester.tap(find.text('משניות').first);
      await tester.pump();

      // The tap must push the SPECIFIC ContentHierarchyRoute for Mishnayos
      // via context.router — not merely "some exception happened", which
      // would also pass for an unrelated build error introduced by a
      // future regression.
      verify(
        () => router.push<Object?>(
          any(
            that: isA<ContentHierarchyRoute>().having(
              (r) => r.args?.curriculumId,
              'curriculumId',
              CurriculumId.mishnayos.storageKey,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
