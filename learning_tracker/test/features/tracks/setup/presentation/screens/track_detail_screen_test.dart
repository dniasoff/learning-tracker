/// Regression tests for the Track Detail screen (W5-B / Task #16).
///
/// Asserts the W5-B copy + styling contract:
///
/// 1. Dual progress labels — the header surfaces two explicit numbers:
///    "Track progress: X%" (current cycle since track activation) and
///    "Lifetime: Y%" (lifetime tier) — both sourced from
///    [trackDualProgressMetricsProvider]. This replaces the legacy single
///    "Progress: X%" label so users distinguish engagement from accumulated
///    knowledge.
///
/// 2. Differentiated bulk-mark tile — the bulk-prior action (which opens
///    [BulkMarkScreen]) renders with secondary / outlined styling and the
///    new "Mark as previously learned" copy, so users cannot confuse the
///    historical-learning path with a live "Mark complete" action.
///
/// See `docs/planning/progress-ia-redesign.md` §9 / Task #16.
@Tags(['tracks', 'track_detail'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/test_database.dart';

const _profileId = 0;
const _trackId = 1;

/// Pin the Hebrew Terms toggle off so assertions can target English copy
/// deterministically — the default value depends on the underlying
/// preference store which is unavailable in widget tests.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

// ── Fixture helpers ────────────────────────────────────────────────────────

CurriculumTrack _track({
  int id = _trackId,
  int profileId = _profileId,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculum.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

TrackDualProgressMetric _dualMetric({
  int trackId = _trackId,
  CurriculumId curriculum = CurriculumId.mishnayos,
  double currentCycle = 0.0,
  double lifetime = 0.0,
}) => TrackDualProgressMetric(
  trackId: trackId,
  trackLabel: curriculum.storageKey,
  curriculumId: curriculum,
  currentCyclePercentage: currentCycle,
  lifetimePercentage: lifetime,
  isProgramTrack: false,
);

/// Overrides every external dependency [TrackDetailScreen] reads so the
/// screen renders synchronously off in-memory data — no real Drift DB
/// queries beyond the user DB (used for the goal lookup).
List<Override> _overridesFor({
  required UserDatabase db,
  required CurriculumTrack track,
  required CurriculumId curriculum,
  required double currentCycle,
  required double lifetime,
}) {
  return [
    userDatabaseProvider.overrideWith((ref) => db),
    useHebrewTermsProvider.overrideWith(
      () => _UseHebrewTermsOverride(useHebrew: false),
    ),
    dashboardTrackCompletionPercentageProvider(
      track.id,
    ).overrideWith((ref) async => currentCycle),
    dashboardHasProgramEnrollmentProvider(
      curriculum,
    ).overrideWith((ref) async => false),
    scopedItemCountProvider(curriculum).overrideWith((ref) async => 100),
    trackDualProgressMetricsProvider(track.profileId).overrideWith(
      (ref) async => [
        _dualMetric(
          trackId: track.id,
          curriculum: curriculum,
          currentCycle: currentCycle,
          lifetime: lifetime,
        ),
      ],
    ),
  ];
}

Widget _wrap({
  required List<Override> overrides,
  required CurriculumTrack track,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackDetailScreen(track: track),
    ),
  );
}

void main() {
  late UserDatabase db;

  setUp(() async {
    db = createTestUserDatabase();
    await seedProfileZero(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Track Detail — dual progress labels (Task #16)', () {
    testWidgets('header shows both "Track progress: X%" and "Lifetime: Y%"', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            // 0.35 → 35%, 0.74 → 74% (adaptive precision: whole numbers, no dp)
            currentCycle: 0.35,
            lifetime: 0.74,
          ),
        ),
      );
      // Let the FutureProviders + goal lookup settle without
      // pumpAndSettle (which would spin on auto-disposing providers).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Track progress: 35%'),
        findsOneWidget,
        reason:
            'Dual progress label must surface the current-cycle pct from '
            'trackDualProgressMetricsProvider as "Track progress: X%".',
      );
      expect(
        find.text('Lifetime: 74%'),
        findsOneWidget,
        reason:
            'Dual progress label must surface the lifetime tier pct from '
            'trackDualProgressMetricsProvider as "Lifetime: Y%".',
      );
    });

    testWidgets('zero-valued metrics still render both labels at 0%', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Both labels must render even when the user has no progress yet,
      // so the dual-progress contract is the same in empty state.
      expect(find.text('Track progress: 0%'), findsOneWidget);
      expect(find.text('Lifetime: 0%'), findsOneWidget);
    });
  });

  group('Track Detail — differentiated bulk-prior tile (Task #16)', () {
    testWidgets(
      'bulk-prior tile uses outlined/secondary styling with new "previously learned" copy',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            track: track,
            overrides: _overridesFor(
              db: db,
              track: track,
              curriculum: CurriculumId.mishnayos,
              currentCycle: 0.1,
              lifetime: 0.2,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // New copy — the bulk-prior tile no longer says "Mark Content Done";
        // it now says "Mark as previously learned" to signal the historical
        // / lifetime nature of the action.
        expect(
          find.text('Mark as previously learned'),
          findsOneWidget,
          reason:
              'Bulk-prior tile must use the new "previously learned" copy so '
              'it cannot be confused with a live "Mark complete" action.',
        );
        expect(
          find.text('Mark Content Done'),
          findsNothing,
          reason: 'Legacy bulk-mark copy must be replaced.',
        );

        // Visual differentiation — the tile must carry an outlined shape and
        // a tinted background, distinct from the neighbouring "Edit" /
        // "Delete" plain ListTiles. We assert the concrete ShapeBorder /
        // tileColor properties so a regression that drops the outline fails.
        final bulkTileFinder = find.byKey(
          const ValueKey('trackDetail.bulkPriorTile'),
        );
        expect(bulkTileFinder, findsOneWidget);

        final bulkTile = tester.widget<ListTile>(bulkTileFinder);
        expect(
          bulkTile.shape,
          isA<RoundedRectangleBorder>(),
          reason: 'Bulk-prior tile must have a RoundedRectangleBorder.',
        );
        final shape = bulkTile.shape! as RoundedRectangleBorder;
        expect(
          shape.side.width,
          greaterThan(0),
          reason:
              'Bulk-prior tile must render a non-zero border (outlined) to '
              'differentiate it from primary action tiles.',
        );
        expect(
          shape.side.color,
          isNot(equals(const Color(0x00000000))),
          reason:
              'Bulk-prior tile outline must use a visible (non-transparent) '
              'colour so the secondary styling is perceptible.',
        );
        expect(
          bulkTile.tileColor,
          isNotNull,
          reason:
              'Bulk-prior tile must apply a tileColor tint as part of the '
              'secondary visual treatment.',
        );

        // Cross-check against a sibling ListTile (Edit Track) — that one
        // MUST NOT carry the outline, proving the styling difference is real.
        final editTileFinder = find.ancestor(
          of: find.text('Edit Track'),
          matching: find.byType(ListTile),
        );
        expect(editTileFinder, findsOneWidget);
        final editTile = tester.widget<ListTile>(editTileFinder);
        // Edit tile has no shape (or a shape without a visible border).
        if (editTile.shape is RoundedRectangleBorder) {
          final editShape = editTile.shape! as RoundedRectangleBorder;
          expect(
            editShape.side.width,
            equals(0.0),
            reason:
                'Sibling Edit tile must NOT carry the bulk-prior outline — '
                'the visual contrast is the whole point of the differentiation.',
          );
        }
        expect(
          editTile.tileColor,
          isNull,
          reason:
              'Sibling Edit tile must not be tinted; only the bulk-prior '
              'tile carries the secondary tile colour.',
        );
      },
    );
  });
}
