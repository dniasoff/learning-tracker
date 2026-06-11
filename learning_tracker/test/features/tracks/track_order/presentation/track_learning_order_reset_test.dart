// Reset-refresh regression for TrackLearningOrderScreen (P2):
// after confirming "Reset to Default Order" the on-screen list must reliably
// re-read and show the restored default order, even when a stale custom-order
// read is still in flight and resolves *after* the reset's own read.

@Tags(['tracks', 'track_learning_order'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/repositories/track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

const _kTrackId = 1;
const _kCurriculumId = CurriculumId.mishnayos;

LearningOrderItem _item(String ref, int sortOrder, {bool custom = false}) =>
    LearningOrderItem(
      sefariaRef: ref,
      displayNameHe: ref,
      displayNameEn: ref,
      userSortOrder: sortOrder,
      isCustomOrdered: custom,
    );

/// Repository whose sedarim reads complete on the test's command, so the test
/// controls the resolution order and can model the stale-read race.
class _ControlledTrackRepository implements TrackLearningOrderRepository {
  final List<Completer<List<LearningOrderItem>>> sedarimReads = [];
  bool wasReset = false;

  @override
  Future<List<LearningOrderItem>> getSedarimOrder(
    int trackId,
    CurriculumId curriculumId,
  ) {
    final completer = Completer<List<LearningOrderItem>>();
    sedarimReads.add(completer);
    return completer.future;
  }

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<void> saveSedarimOrder(int trackId, List<LearningOrderItem> items)
      async {}

  @override
  Future<void> saveMasechtosOrder(int trackId, List<LearningOrderItem> items)
      async {}

  @override
  Future<void> resetToDefault(int trackId) async {
    wasReset = true;
  }
}

List<String> _renderedSedarim(WidgetTester tester) {
  return tester
      .widgetList<DraggableOrderItem>(find.byType(DraggableOrderItem))
      .map((w) => w.item.sefariaRef)
      .toList();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'reset → sedarim list reliably reflects the default order even when a '
    'stale custom-order read resolves after the reset',
    (tester) async {
      final repo = _ControlledTrackRepository();

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            userDatabaseProvider.overrideWith((ref) => inMemoryDb()),
            trackLearningOrderRepositoryProvider.overrideWithValue(repo),
            overdueCountForCurriculumProvider(
              _kCurriculumId,
            ).overrideWith((ref) async => 0),
            useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TrackLearningOrderScreen(
              trackId: _kTrackId,
              curriculumId: _kCurriculumId,
            ),
          ),
        ),
      );
      await tester.pump();

      // Resolve the initial sedarim read with a CUSTOM order.
      expect(repo.sedarimReads, hasLength(1));
      repo.sedarimReads[0].complete([
        _item('Seder_Moed', 0, custom: true),
        _item('Seder_Zeraim', 1, custom: true),
      ]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_renderedSedarim(tester), const ['Seder_Moed', 'Seder_Zeraim']);

      // Tap reset and confirm. The reset handler invalidates the providers,
      // triggering a fresh sedarim read (sedarimReads[1]).
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(repo.wasReset, isTrue);
      expect(repo.sedarimReads, hasLength(2));

      // The post-reset read resolves with the DEFAULT (natural) order.
      repo.sedarimReads[1].complete([
        _item('Seder_Zeraim', 0),
        _item('Seder_Moed', 1),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The UI must deterministically show the restored default order.
      expect(_renderedSedarim(tester), const ['Seder_Zeraim', 'Seder_Moed']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}
