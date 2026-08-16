/// AUD-content_browsing-01 regression: the [ContentItemTile] stage-breakdown
/// bottom sheet (opened by long-pressing a completed leaf item) had two
/// hard-coded English literals — the "Review History" header and the
/// "No completions yet." empty-state body — leaking English into the Hebrew
/// UI. This test was RED before both strings were routed through
/// AppLocalizations.
@Tags(['content_browsing', 'i18n'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _curriculum = CurriculumId.mishnayos;

final _item = ContentItem(
  curriculumId: _curriculum.storageKey,
  level1: 'Berakhot',
  level2: '1',
  level3: '1',
  displayNameHe: 'ברכות א׳ א׳',
  displayNameEn: 'Berakhot 1:1',
  sefariaRef: 'Mishnah_Berakhot_1.1',
  sortOrder: 0,
  isLeaf: true,
);

/// Minimal fake — only [getStagesForCurriculum] is exercised by the sheet.
class _FakeStageRepository implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async {
    return [
      const StageDefinition(
        curriculumId: _curriculum,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _host({required Locale locale, required Map<int, int> breakdown}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWithValue(false),
      itemStageBreakdownProvider((
        curriculumId: _curriculum.storageKey,
        sefariaRef: _item.sefariaRef,
      )).overrideWith((ref) async => breakdown),
      stageDefinitionRepositoryProvider(
        _curriculum,
      ).overrideWithValue(_FakeStageRepository()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ContentItemTile(
          item: _item,
          curriculum: _curriculum,
          onTap: () {},
          reviewCount: 1,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ContentItemTile stage-breakdown sheet — AUD-content_browsing-01: '
      'must be localized', () {
    testWidgets('Hebrew locale: sheet header renders "היסטוריית חזרות" not '
        '"Review History"', (tester) async {
      await tester.pumpWidget(
        _host(locale: const Locale('he'), breakdown: {1: 3}),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ContentItemTile));
      await tester.pumpAndSettle();

      expect(
        find.text('היסטוריית חזרות'),
        findsOneWidget,
        reason:
            'AUD-content_browsing-01: sheet header must use l10n so '
            'Hebrew locale shows "היסטוריית חזרות" not the hard-coded '
            'English "Review History"',
      );
      expect(find.text('Review History'), findsNothing);
    });

    testWidgets('Hebrew locale: empty breakdown renders "אין השלמות עדיין" not '
        '"No completions yet."', (tester) async {
      await tester.pumpWidget(
        _host(locale: const Locale('he'), breakdown: const {}),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ContentItemTile));
      await tester.pumpAndSettle();

      expect(find.text('אין השלמות עדיין'), findsOneWidget);
      expect(find.text('No completions yet.'), findsNothing);
      expect(find.text('No completions yet'), findsNothing);
    });

    testWidgets('English locale: sheet header and empty-state still render in '
        'English after fix', (tester) async {
      await tester.pumpWidget(
        _host(locale: const Locale('en'), breakdown: const {}),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ContentItemTile));
      await tester.pumpAndSettle();

      expect(find.text('Review History'), findsOneWidget);
      expect(find.text('No completions yet'), findsOneWidget);
    });
  });
}
