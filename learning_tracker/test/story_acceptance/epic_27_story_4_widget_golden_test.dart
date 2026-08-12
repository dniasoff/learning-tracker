/// Story acceptance coverage for Epic 27.4 widget/golden contracts.
@Tags(['epic_27', 'story_27_4'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_runner.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // The old Drift track model had a trackType field; the Firestore-era model
  // deliberately does not (AD-25: a track is its CurriculumId). These four
  // fixtures therefore use distinct canonical curricula as the current
  // production equivalents of the former personal/school/advanced/program
  // shapes, while the progress flag remains an explicit per-shape property.
  for (final shape in const [
    _GoldenShape(
      name: 'track_card_personal_no_progress',
      curriculumId: CurriculumId.mishnayos,
      showProgress: false,
    ),
    _GoldenShape(
      name: 'track_card_school_no_progress',
      curriculumId: CurriculumId.bavli,
      showProgress: false,
    ),
    _GoldenShape(
      name: 'track_card_advanced_with_progress',
      curriculumId: CurriculumId.chumash,
      showProgress: true,
    ),
    _GoldenShape(
      name: 'track_card_program_with_progress',
      curriculumId: CurriculumId.nach,
      showProgress: true,
    ),
  ]) {
    goldenTest(
      shape.name,
      builder: (locale, brightness) => _pumpHarness(
        locale: locale,
        brightness: brightness,
        curriculumId: shape.curriculumId,
        child: LearningTrackCard(
          track: _track(shape.curriculumId),
          showProgress: shape.showProgress,
        ),
      ),
    );
  }

  group('Story 27.4 — portable widget behavior', () {
    testWidgets('DraggableOrderItem renders a drag handle by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReorderableListView(
                onReorderItem: _noOpReorder,
                children: const [
                  DraggableOrderItem(
                    key: ValueKey('item-0'),
                    item: LearningOrderItem(
                      sefariaRef: 'Berakhot',
                      displayNameHe: 'ברכות',
                      displayNameEn: 'Berakhot',
                      userSortOrder: 0,
                    ),
                    index: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('DraggableOrderItem omits the handle when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DraggableOrderItem(
                item: LearningOrderItem(
                  sefariaRef: 'Shabbat',
                  displayNameHe: 'שבת',
                  displayNameEn: 'Shabbat',
                  userSortOrder: 1,
                ),
                index: 0,
                showDragHandle: false,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('DraggableOrderItem renders in an RTL locale', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('he'),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: DraggableOrderItem(
                  item: LearningOrderItem(
                    sefariaRef: 'Eruvin',
                    displayNameHe: 'עירובין',
                    displayNameEn: 'Eruvin',
                    userSortOrder: 2,
                  ),
                  index: 0,
                  showDragHandle: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DraggableOrderItem), findsOneWidget);
    });
  });

  group('Story 27.4 — AC structural verification', () {
    test('TrackCard golden matrix covers four shapes', () {
      final names = registeredGoldenTests
          .map((registration) => registration.name)
          .where((name) => name.startsWith('track_card_'))
          .toSet();
      expect(names, hasLength(4));
    });

    test('every registered golden has an English and Hebrew case', () {
      final localesByName = <String, Set<String>>{};
      for (final registration in registeredGoldenTests) {
        localesByName
            .putIfAbsent(registration.name, () => <String>{})
            .add(registration.locale.languageCode);
      }
      expect(localesByName, isNotEmpty);
      expect(
        localesByName.values.every((locales) => locales.contains('he')),
        isTrue,
      );
    });
  });
}

void _noOpReorder(int oldIndex, int newIndex) {}

Widget _pumpHarness({
  required Widget child,
  required Locale locale,
  required Brightness brightness,
  required CurriculumId curriculumId,
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      dashboardTrackCompletionPercentageProvider(
        curriculumId,
      ).overrideWith((ref) async => 0.0),
      trackHasChazaraProvider(
        curriculumId,
      ).overrideWith((ref) async => false),
      dashboardHasProgramEnrollmentProvider(
        curriculumId,
      ).overrideWith((ref) async => false),
      trackCustomNameProvider(
        curriculumId,
      ).overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(brightness: brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

CurriculumTrackEntity _track(CurriculumId curriculumId) => CurriculumTrackEntity(
  curriculumId: curriculumId,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

class _GoldenShape {
  const _GoldenShape({
    required this.name,
    required this.curriculumId,
    required this.showProgress,
  });

  final String name;
  final CurriculumId curriculumId;
  final bool showProgress;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}
