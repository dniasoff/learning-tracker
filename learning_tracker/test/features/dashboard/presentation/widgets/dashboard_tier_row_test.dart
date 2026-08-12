/// Widget tests for the Dashboard refinement (Task #14 / Phase D):
///
///   - The shared [ProgressTierCounterRow] is mounted on the Dashboard body.
///   - Adult mode renders 3 counters (no points).
///   - Child mode renders 4 counters (includes points).
///   - Active-track rows show dual "Track progress" / "Lifetime" labels
///     wired to [trackDualProgressMetricsProvider].
///   - The legacy "ACTIVE TRACKS" stat card no longer appears.
@Tags(['dashboard', 'tier_counter'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show firestoreLearningLedgerRepositoryProvider;
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart'
    show learningLedgerRepositoryProvider;
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/progress_tier_counter_row.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'dashboard-tier-uid';
const _profileId = 'dashboard-tier-profile-ulid';

// ── Overrides ──────────────────────────────────────────────────────────────

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final String _id;
  @override
  String? build() => _id;
}

/// Pin the Hebrew Terms toggle off so assertions can target English copy
/// deterministically — the toggle default depends on environment.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

// ── Fixture helpers ────────────────────────────────────────────────────────

JourneyViewModel _journey({
  int unit = 0,
  int aggregate = 0,
  int curriculum = 0,
}) => JourneyViewModel(
  curricula: const [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: unit,
  aggregateLevelSiyumimCount: aggregate,
  curriculumLevelSiyumimCount: curriculum,
);

LifetimeTotals _lifetimeTotals({int learned = 0, int total = 0}) =>
    LifetimeTotals(
      learnedSections: learned,
      totalSections: total,
      totalCurricula: CurriculumId.values.length,
    );

CurriculumTrackEntity _track({
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => CurriculumTrackEntity(
  curriculumId: curriculum,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

TrackDualProgressMetric _dualMetric({
  required CurriculumId curriculum,
  double currentCycle = 0.0,
  double lifetime = 0.0,
}) => TrackDualProgressMetric(
  trackLabel: curriculum.storageKey,
  curriculumId: curriculum,
  currentCyclePercentage: currentCycle,
  lifetimePercentage: lifetime,
  isProgramTrack: false,
);

/// Build the full set of overrides needed to render [DashboardScreen] with
/// at least one active track (so the body — and therefore the counter row —
/// renders instead of the empty-state placeholder).
List<Override> _overridesFor({
  required ProfileMode userMode,
  required int currentStreak,
  required JourneyViewModel journey,
  required LifetimeTotals lifetime,
  required List<CurriculumTrackEntity> tracks,
  required List<TrackDualProgressMetric> dualMetrics,
  int points = 0,
}) {
  return [
    activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(_profileId)),
    useHebrewTermsProvider.overrideWith(
      () => _UseHebrewTermsOverride(useHebrew: false),
    ),
    dashboardActiveCurriculaProvider.overrideWith(
      (ref) => Future.value(
        tracks
            .map(
              (t) => CurriculumId.values.firstWhere(
                (c) => c == t.curriculumId,
                orElse: () => CurriculumId.mishnayos,
              ),
            )
            .toList(),
      ),
    ),
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(
        tracks
            .map(
              (t) => CurriculumId.values.firstWhere(
                (c) => c == t.curriculumId,
                orElse: () => CurriculumId.mishnayos,
              ),
            )
            .toList(),
      ),
    ),
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(tracks),
    ),
    dashboardUserModeProvider.overrideWith((ref) => Future.value(userMode)),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((
        currentStreak: currentStreak,
        maxStreak: currentStreak,
      )),
    ),
    dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(points)),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        StreakRecoveryInfo(wasRecovered: false, currentStreak: currentStreak),
      ),
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    journeyViewModelProvider.overrideWith((ref) => Future.value(journey)),
    lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
      (ref) => Future.value(lifetime),
    ),
    trackDualProgressMetricsProvider.overrideWith(
      (ref) => Future.value(dualMetrics),
    ),
    // Mark every curriculum as non-program-enrolled so the active-track card
    // takes the self-paced branch (avoids the program-calendar provider tree).
    for (final c in CurriculumId.values)
      dashboardHasProgramEnrollmentProvider(
        c,
      ).overrideWith((ref) => Future.value(false)),
  ];
}

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardScreen(),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Dashboard — ProgressTierCounterRow integration', () {
    testWidgets(
      'adult mode renders 3 counters (streak / siyumim / lifetime), no points',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: ProfileMode.adult,
              currentStreak: 7,
              // 3 unit + 1 aggregate + 0 curriculum = 4 siyumim total
              journey: _journey(unit: 3, aggregate: 1),
              lifetime: _lifetimeTotals(learned: 42, total: 100),
              points: 250, // adult mode must NOT render this
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  curriculum: CurriculumId.mishnayos,
                  currentCycle: 0.5,
                  lifetime: 0.42,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The three engagement / achievement / lifetime tiles: short noun
        // labels with the big formatted value above each. The numeric
        // values are scoped inside the ProgressTierCounterRow because the
        // surrounding dashboard renders the same digits elsewhere
        // (active-track tile, etc.) and would otherwise satisfy a global
        // `find.text('7')`.
        Finder inTileRow(String text) => find.descendant(
          of: find.byType(ProgressTierCounterRow),
          matching: find.text(text),
        );
        expect(inTileRow('7'), findsOneWidget); // streak value
        expect(inTileRow('4'), findsOneWidget); // siyumim value
        expect(inTileRow('42'), findsOneWidget); // lifetime value
        expect(inTileRow('Streak'), findsOneWidget);
        expect(inTileRow('Siyumim'), findsOneWidget);
        expect(inTileRow('Lifetime'), findsOneWidget);
        // Adult mode must NOT render the ⭐ points counter even when the
        // dashboardGlobalPointsProvider has a non-zero value.
        expect(inTileRow('Points'), findsNothing);
        expect(inTileRow('250'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('child mode renders 4 counters (adds ⭐ points)', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          overrides: _overridesFor(
            userMode: ProfileMode.child,
            currentStreak: 3,
            journey: _journey(unit: 2),
            lifetime: _lifetimeTotals(learned: 15, total: 100),
            points: 1200,
            tracks: [track],
            dualMetrics: [_dualMetric(curriculum: CurriculumId.mishnayos)],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Scope the value-text assertions inside the tile row — dashboard
      // also renders track tiles that may contain the same digits.
      Finder inTileRow(String text) => find.descendant(
        of: find.byType(ProgressTierCounterRow),
        matching: find.text(text),
      );
      expect(inTileRow('3'), findsOneWidget); // streak value
      expect(inTileRow('2'), findsOneWidget); // siyumim value
      expect(inTileRow('15'), findsOneWidget); // lifetime value
      expect(inTileRow('1,200'), findsOneWidget); // points value formatted
      expect(inTileRow('Streak'), findsOneWidget);
      expect(inTileRow('Siyumim'), findsOneWidget);
      expect(inTileRow('Lifetime'), findsOneWidget);
      // ⭐ points counter must appear in child mode.
      expect(inTileRow('Points'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('Dashboard — dual per-track labels', () {
    testWidgets(
      'active-track card shows both "Track progress: X%" and "Lifetime: Y%"',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            overrides: _overridesFor(
              userMode: ProfileMode.adult,
              currentStreak: 0,
              journey: _journey(),
              lifetime: _lifetimeTotals(),
              tracks: [track],
              dualMetrics: [
                _dualMetric(
                  curriculum: CurriculumId.mishnayos,
                  // 0.35 → 35%, 0.74 → 74% (rounded via formatFractionAsPercent)
                  currentCycle: 0.35,
                  lifetime: 0.74,
                ),
              ],
            ),
          ),
        );
        // Two pumps to allow the futures + stream to settle without using
        // pumpAndSettle (which would spin forever on auto-refreshing streams).
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The active-tracks carousel lives near the bottom of the dashboard
        // ListView and is outside the default test viewport (800×600).
        // Scroll it into view so the per-track card renders.
        await tester.scrollUntilVisible(
          find.byType(PageView),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Both labels are rendered side-by-side in the card footer.
        // `formatFractionAsPercent` now uses adaptive precision: whole numbers
        // have no decimal, non-whole values use 1 decimal place.
        // 0.35 → "35%" (whole when rounded to 1 dp), 0.74 → "74%".
        expect(find.text('Track progress: 35%'), findsOneWidget);
        expect(find.text('Lifetime: 74%'), findsOneWidget);
        // Legacy single-label format must be gone.
        expect(find.textContaining('Since reactivation'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Dashboard — legacy "ACTIVE TRACKS" stat card removed', () {
    testWidgets('no widget displays the legacy "ACTIVE TRACKS" stat tile', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          overrides: _overridesFor(
            userMode: ProfileMode.adult,
            currentStreak: 0,
            journey: _journey(),
            lifetime: _lifetimeTotals(),
            tracks: [track],
            dualMetrics: [_dualMetric(curriculum: CurriculumId.mishnayos)],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Neither casing should appear — the redundant counter card is gone.
      expect(find.text('ACTIVE TRACKS'), findsNothing);
      expect(find.text('Active Tracks'.toUpperCase()), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // F23 — Integration test driving the REAL journeyViewModelProvider.
  //
  // The other tests in this file stub `journeyViewModelProvider` with a
  // synthetic [JourneyViewModel], so a regression in the upstream tally
  // (milestone detection, three-level counter aggregation, ledger DAO
  // shape) would leave the dashboard silently showing zeros while the
  // stub-fed tests still pass. This integration test seeds the actual
  // `learning_ledger` table on an in-memory Drift database, mounts the
  // real Dashboard, and asserts the counter row reflects the true totals.
  //
  // Reuses the seeding pattern from
  // `test/features/progress/presentation/providers/journey_providers_test.dart`.
  // ─────────────────────────────────────────────────────────────────────────

  group('Dashboard — REAL journeyViewModelProvider integration (F23)', () {
    // Mishnayos Seder Zeraim has 11 masechtas. Seeding all 11 produces
    // 11 unit-level siyumim + 1 aggregate-level siyum (Zeraim complete) +
    // 0 curriculum-level siyumim = 12 total siyumim on the counter row.
    const zeraimMasechtos = [
      'Berakhot',
      'Peah',
      'Demai',
      'Kilayim',
      'Sheviit',
      'Terumot',
      'Maasrot',
      'Maaser Sheni',
      'Challah',
      'Orlah',
      'Bikkurim',
    ];

    Future<void> seedMasechtaLedger(
      FakeFirebaseFirestore firestore, {
      required String masechta,
      required DateTime at,
      required String ulid,
    }) {
      return seedLedgerEntry(
        firestore,
        uid: _uid,
        profileId: _profileId,
        ulid: ulid,
        curriculumId: CurriculumId.mishnayos,
        entryScope: 'masechta',
        unitIdentifier: masechta,
        unitDisplayNameHe: masechta,
        unitDisplayNameEn: masechta,
        trackType: 'personal',
        completedAt: at,
      );
    }

    /// Representative Mishnayos content list — six sederim, full masechta
    /// counts (11/12/7/10/11/12 = 63). Sufficient to exercise per-seder
    /// detection. Lifted directly from `journey_providers_test.dart` and
    /// kept inline so the test is self-contained.
    List<ContentItem> mishnayosContent() {
      final sederim = <String, List<String>>{
        'Zeraim': zeraimMasechtos,
        'Moed': [
          'Shabbat',
          'Eruvin',
          'Pesachim',
          'Shekalim',
          'Yoma',
          'Sukkah',
          'Beitzah',
          'Rosh Hashanah',
          'Taanit',
          'Megillah',
          'Moed Katan',
          'Chagigah',
        ],
        'Nashim': [
          'Yevamot',
          'Ketubot',
          'Nedarim',
          'Nazir',
          'Sotah',
          'Gittin',
          'Kiddushin',
        ],
        'Nezikin': [
          'Bava Kamma',
          'Bava Metzia',
          'Bava Batra',
          'Sanhedrin',
          'Makkot',
          'Shevuot',
          'Eduyot',
          'Avodah Zarah',
          'Avot',
          'Horayot',
        ],
        'Kodashim': [
          'Zevachim',
          'Menachot',
          'Chullin',
          'Bekhorot',
          'Arakhin',
          'Temurah',
          'Keritot',
          'Meilah',
          'Tamid',
          'Middot',
          'Kinnim',
        ],
        'Tahorot': [
          'Kelim',
          'Oholot',
          'Negaim',
          'Parah',
          'Tahorot',
          'Mikvaot',
          'Niddah',
          'Makhshirin',
          'Zavim',
          'Tevul Yom',
          'Yadayim',
          'Uktzin',
        ],
      };
      final items = <ContentItem>[];
      var sortOrder = 0;
      for (final entry in sederim.entries) {
        for (final masechta in entry.value) {
          items.add(
            ContentItem(
              curriculumId: CurriculumId.mishnayos.storageKey,
              level1: entry.key,
              level2: masechta,
              displayNameHe: masechta,
              displayNameEn: masechta,
              sefariaRef: 'Mishnah $masechta 1.1',
              sortOrder: sortOrder++,
              isLeaf: true,
            ),
          );
        }
      }
      return items;
    }

    /// Real-Firestore integration override builder — wires the fake Firestore and
    /// the curriculum-content provider for Mishnayos, then keeps everything
    /// else from [_overridesFor] EXCEPT the `journeyViewModelProvider`
    /// override (which we deliberately omit so the REAL provider runs).
    List<Override> integrationOverrides({
      required FakeFirebaseFirestore firestore,
      required int currentStreak,
      required LifetimeTotals lifetime,
      required List<CurriculumTrackEntity> tracks,
      required List<TrackDualProgressMetric> dualMetrics,
    }) {
      return [
        activeProfileIdProvider.overrideWith(
          () => _ProfileIdOverride(_profileId),
        ),
        firestoreLearningLedgerRepositoryProvider.overrideWith(
          (ref) async => FirestoreLearningLedgerRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
        learningLedgerRepositoryProvider.overrideWith(
          (ref) => FirestoreLearningLedgerRepositoryAdapter(
            ref: ref,
            activeProfileMode: ProfileMode.adult,
          ),
        ),
        useHebrewTermsProvider.overrideWith(
          () => _UseHebrewTermsOverride(useHebrew: false),
        ),
        // The real journeyViewModelProvider depends on
        // `activeCurriculaProvider` + `curriculumContentProvider(...)`. We
        // pin Mishnayos as active and supply the full content list so the
        // milestone detector has the per-seder grouping it needs.
        activeCurriculaProvider.overrideWith(
          (ref) => Future.value(const [CurriculumId.mishnayos]),
        ),
        curriculumContentProvider(
          CurriculumId.mishnayos,
        ).overrideWith((ref) => Future.value(mishnayosContent())),
        // Dashboard scaffolding — the same shape as `_overridesFor` so the
        // body renders past the loading + empty-state gates.
        dashboardActiveCurriculaProvider.overrideWith(
          (ref) => Future.value(
            tracks
                .map(
                  (t) => CurriculumId.values.firstWhere(
                    (c) => c == t.curriculumId,
                    orElse: () => CurriculumId.mishnayos,
                  ),
                )
                .toList(),
          ),
        ),
        dashboardActiveCurriculaStreamProvider.overrideWith(
          (ref) => Stream.value(
            tracks
                .map(
                  (t) => CurriculumId.values.firstWhere(
                    (c) => c == t.curriculumId,
                    orElse: () => CurriculumId.mishnayos,
                  ),
                )
                .toList(),
          ),
        ),
        dashboardActiveTracksStreamProvider.overrideWith(
          (ref) => Stream.value(tracks),
        ),
        dashboardUserModeProvider.overrideWith(
          (ref) => Future.value(ProfileMode.adult),
        ),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((
            currentStreak: currentStreak,
            maxStreak: currentStreak,
          )),
        ),
        dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
        dashboardStreakRecoveryProvider.overrideWith(
          (ref) => Future.value(
            StreakRecoveryInfo(
              wasRecovered: false,
              currentStreak: currentStreak,
            ),
          ),
        ),
        allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
        lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
          (ref) => Future.value(lifetime),
        ),
        trackDualProgressMetricsProvider.overrideWith(
          (ref) => Future.value(dualMetrics),
        ),
        for (final c in CurriculumId.values)
          dashboardHasProgramEnrollmentProvider(
            c,
          ).overrideWith((ref) => Future.value(false)),
      ];
    }

    testWidgets(
      'siyumim counter reflects the REAL three-level breakdown when the '
      'ledger has Seder Zeraim fully complete (11 unit + 1 aggregate + 0 '
      'curriculum = 12 total)',
      (tester) async {
        final firestore = createFakeFirestore(authenticatedUid: _uid);

        // Seed all 11 Zeraim masechtos into the ledger — the real journey
        // provider should compute 11 unit-level siyumim + 1 aggregate-level
        // (Zeraim complete) + 0 curriculum-level = 12 total.
        final base = DateTime(2026, 1, 1);
        for (var i = 0; i < zeraimMasechtos.length; i++) {
          await seedMasechtaLedger(
            firestore,
            masechta: zeraimMasechtos[i],
            at: base.add(Duration(days: i)),
            ulid: 'ledger-$i',
          );
        }

        final track = _track();
        await tester.pumpWidget(
          ProviderScope(
            overrides: integrationOverrides(
              firestore: firestore,
              currentStreak: 5,
              lifetime: _lifetimeTotals(learned: 200),
              tracks: [track],
              dualMetrics: [_dualMetric(curriculum: CurriculumId.mishnayos)],
            ),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DashboardScreen(),
            ),
          ),
        );
        // Multiple pumps to let the real provider's chained futures (the
        // ledger DAO read, the content load, the milestone aggregation)
        // resolve before assertions run.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // 11 unit + 1 aggregate + 0 curriculum = 12 siyumim displayed on
        // the counter row's middle slot. Scope inside ProgressTierCounterRow
        // so other dashboard digits don't confound the assertion.
        Finder inTileRow(String text) => find.descendant(
          of: find.byType(ProgressTierCounterRow),
          matching: find.text(text),
        );
        expect(
          inTileRow('12'),
          findsOneWidget,
          reason:
              'real journeyViewModelProvider must report 11 unit + 1 '
              'aggregate + 0 curriculum = 12 total siyumim from a fully-'
              'seeded Seder Zeraim ledger',
        );
        expect(inTileRow('Siyumim'), findsOneWidget);

        // The streak counter (stubbed) sanity-check — confirms the row is
        // mounted and rendering past the loading state.
        expect(inTileRow('5'), findsOneWidget); // streak value
        expect(inTileRow('Streak'), findsOneWidget);
        // Lifetime counter — also stubbed (lifetime is its own provider).
        expect(inTileRow('200'), findsOneWidget); // lifetime value
        expect(inTileRow('Lifetime'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'empty ledger → siyumim counter shows 0 even when the dashboard '
      'is otherwise fully populated',
      (tester) async {
        final firestore = createFakeFirestore(authenticatedUid: _uid);
        // Deliberately seed NO ledger entries — the real provider should
        // emit a JourneyViewModel with all three counters at 0.

        final track = _track();
        await tester.pumpWidget(
          ProviderScope(
            overrides: integrationOverrides(
              firestore: firestore,
              currentStreak: 0,
              lifetime: _lifetimeTotals(),
              tracks: [track],
              dualMetrics: [_dualMetric(curriculum: CurriculumId.mishnayos)],
            ),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DashboardScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The real provider returns 0/0/0 → every counter renders "0".
        // The siyumim tile is identified by its 'Siyumim' label sitting
        // next to a '0' value. Critically, this assertion uses the REAL
        // provider — if a milestone tally regression produced a non-zero
        // number for an empty ledger, the streak/lifetime/points tiles
        // would still read 0 (stubbed) but siyumim would diverge.
        // Scope to the tile row — the dashboard background may contain
        // other '0' or 'Siyumim' strings (e.g. track rows).
        Finder inTileRow(String text) => find.descendant(
          of: find.byType(ProgressTierCounterRow),
          matching: find.text(text),
        );
        expect(inTileRow('Siyumim'), findsOneWidget);
        // Adult mode → 3 tiles (Streak / Siyumim / Lifetime), all reading '0'.
        expect(inTileRow('0'), findsNWidgets(3));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
