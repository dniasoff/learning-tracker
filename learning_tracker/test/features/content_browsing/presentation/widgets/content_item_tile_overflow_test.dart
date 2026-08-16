// Overflow guard for the [ContentItemTile] stage-breakdown bottom sheet
// (P2 sheet fix).
//
// Long-pressing a leaf tile opens a showModalBottomSheet whose content Column
// previously had no scroll, so a long per-stage breakdown — or large
// accessibility text — overflowed on short screens. The fix makes the sheet
// `isScrollControlled` and wraps its body in a height-bounded
// SingleChildScrollView.
//
// The sheet is the private `_StageBreakdownSheet`, reachable only via the
// tile's long-press handler — so this guard cannot hand a bare widget to
// [expectNoOverflowAcrossDevices]. Instead it reuses that harness's
// [defaultOverflowMatrix] (the same size × text-scale extremes) and, at each
// corner, actually long-presses the tile, lets the sheet open, and asserts no
// RenderFlex overflow is thrown.

@Tags(['overflow'])
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

import '../../../../helpers/overflow_harness.dart';

const _curriculum = CurriculumId.mishnayos;

final _item = ContentItem(
  curriculumId: _curriculum.storageKey,
  level1: 'Berakhot',
  level2: '1',
  level3: '1',
  displayNameHe: 'ברכות א׳ א׳',
  displayNameEn:
      'Berakhot Chapter One Mishnah One With A Deliberately Long Name',
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
    // Many stages with long names → a tall breakdown that must scroll rather
    // than overflow.
    return List.generate(
      8,
      (i) => StageDefinition(
        curriculumId: curriculumId,
        stageOrder: i + 1,
        stageName: i == 0
            ? 'Learn'
            : 'Chazara ${i + 1} — a deliberately long stage label',
        delayDays: i,
        isDefault: i == 0,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Widget _host() {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWithValue(false),
      // A big per-stage breakdown so the sheet body is taller than a short
      // viewport at large text — exercises the scroll/clamp.
      itemStageBreakdownProvider((
        curriculumId: _curriculum.storageKey,
        sefariaRef: _item.sefariaRef,
      )).overrideWith((ref) async => {for (var i = 1; i <= 8; i++) i: i * 2}),
      stageDefinitionRepositoryProvider(
        _curriculum,
      ).overrideWithValue(_FakeStageRepository()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
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
          // Non-null count > 0 so the long-press breakdown path is enabled.
          reviewCount: 3,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'ContentItemTile stage-breakdown sheet (tall breakdown) does not overflow '
    'across the device matrix',
    (tester) async {
      addTearDown(tester.view.reset);

      for (final c in defaultOverflowMatrix()) {
        tester.view.devicePixelRatio = c.devicePixelRatio;
        tester.view.physicalSize = Size(
          c.size.width * c.devicePixelRatio,
          c.size.height * c.devicePixelRatio,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(c.textScale)),
            child: _host(),
          ),
        );
        await tester.pumpAndSettle();

        // Open the breakdown sheet via the real long-press handler.
        await tester.longPress(find.byType(ContentItemTile));
        await tester.pumpAndSettle();

        // The sheet's per-stage breakdown is rendered (proves it opened).
        expect(
          find.textContaining('Review History'),
          findsOneWidget,
          reason: 'Breakdown sheet should be open at ${c.label}',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'Breakdown sheet overflowed / threw at ${c.label}.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.reset();
      }
    },
  );
}
