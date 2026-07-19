// AUD-tracks-05 (P1, PF-2) regression: TrackLearningOrderScreen's masechtos
// ReorderableListView used the plain (non-.builder) constructor with
// shrinkWrap:true nested inside a SingleChildScrollView. shrinkWrap:true
// forces the sliver to compute its own scroll extent before the outer
// SingleChildScrollView can lay out, so it must realize (build) EVERY row up
// front regardless of viewport — for a curriculum like Mishna Berurah (697
// Simanim) that is 697 DraggableOrderItem widgets built in one frame on an
// ordinary, one-tap "Reorder Learning Order" action.
//
// This test pumps the screen with a 700-item trackMasechtosOrderProvider
// fixture and asserts only a viewport's worth of DraggableOrderItem widgets
// are realized — the signature of a lazy (sliver-backed, non-shrink-wrapped)
// list — plus that the screen settles within pumpAndSettle's bounded frame
// budget instead of hanging under the eager-build cost.

@Tags(['tracks', 'track_learning_order'])
library;

import 'package:flutter/material.dart';
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

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/pump_app.dart';

const _kTrackId = 1;
const _kCurriculumId = CurriculumId.mishnaBerurah;
const _kMasechtosCount = 700;

// A viewport-scale ceiling, not just "less than everything". The original
// `lessThan(_kMasechtosCount)` bound (i.e. lessThan(700)) would still pass
// at 699 realized rows, which is indistinguishable from the eager-build
// defect this test guards against. AC2 requires "only a viewport's worth";
// a phone-sized viewport realizes roughly a dozen ListTile-height rows plus
// RenderSliverList's cacheExtent look-ahead — measured actual on this
// fixture is 9. 50 leaves headroom for larger test viewports/screen
// densities while still failing hard on anything resembling an eager,
// whole-list build.
const _kViewportScaleCeiling = 50;

LearningOrderItem _item(String ref, int sortOrder) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: sortOrder,
  isCustomOrdered: false,
);

/// A track repository whose masechtos order is a large (700-item) fixture,
/// modelling a Mishna Berurah track (697 Simanim in production content).
class _LargeFixtureTrackRepository implements TrackLearningOrderRepository {
  @override
  Future<List<LearningOrderItem>> getSedarimOrder(
    int trackId,
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<List<LearningOrderItem>> getMasechtosOrder(
    int trackId,
    CurriculumId curriculumId,
  ) async => [for (var i = 0; i < _kMasechtosCount; i++) _item('Siman_$i', i)];

  @override
  Future<void> saveSedarimOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {}

  @override
  Future<void> saveMasechtosOrder(
    int trackId,
    List<LearningOrderItem> items,
  ) async {}

  @override
  Future<void> resetToDefault(int trackId) async {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'masechtos section realizes only a viewport worth of DraggableOrderItem '
    'rows for a 700-item (Mishna Berurah-sized) track, not all 700 (PF-2)',
    (tester) async {
      final repo = _LargeFixtureTrackRepository();
      final db = inMemoryDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            trackLearningOrderRepositoryProvider.overrideWithValue(repo),
            overdueCountForCurriculumProvider(
              _kCurriculumId,
            ).overrideWith((ref) async => 0),
            useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
          ],
          child: const TrackLearningOrderScreen(
            trackId: _kTrackId,
            curriculumId: _kCurriculumId,
          ),
        ),
      );

      // Bounded settle: a hard-hanging eager layout must surface as
      // pumpAndSettle's own timeout failure rather than a genuine engine
      // hang (its internal 100-pump safety cap already bounds this, but an
      // explicit timeout keeps the failure message unambiguous).
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );

      final realized = tester
          .widgetList<DraggableOrderItem>(find.byType(DraggableOrderItem))
          .length;

      expect(
        realized,
        lessThan(_kViewportScaleCeiling),
        reason:
            'Only a viewport\'s worth of masechtos rows should be realized '
            'lazily — found $realized of $_kMasechtosCount, which exceeds '
            'the viewport-scale ceiling of $_kViewportScaleCeiling and '
            'indicates every row was eagerly built (the shrinkWrap:true '
            'PF-2 defect). A bound of lessThan($_kMasechtosCount) would '
            'let 699 realized rows pass, which is not "a viewport\'s '
            'worth" per AC2.',
      );
      // A sanity floor: the screen did render *something* — an empty result
      // would trivially satisfy lessThan() without proving the list works.
      expect(realized, greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}
