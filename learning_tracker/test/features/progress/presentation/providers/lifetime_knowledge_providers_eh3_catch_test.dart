/// AUD-progress-06 regression test.
///
/// Two catch blocks in lifetime_knowledge_providers.dart swallowed every
/// exception with `catch (_) { ... }` and no `AppLogger` call:
///
///  * `_computeTrackDualProgressMetric`'s calendar-position lookup — a
///    `programCalendarPositionProvider` failure silently degrades
///    `overdueCount`/`todayDueCount` to a falsely-reassuring 0 with zero
///    breadcrumb.
///  * `_safeLoadLeavesForTrack`'s scoped-content load — a
///    `getScopedContent` failure silently drops the track from
///    `trackDualProgressMetricsProvider`'s output with zero breadcrumb.
///
/// The same file already fixes this exact anti-pattern under the F20 label
/// for `_safeLoadLeaves`/`_safeHeLabelLookup` (logging via
/// `AppLogger.instance.warning(event:, fields:, exception:, stackTrace:)`).
/// These two tests force each failure and assert the breadcrumb now lands
/// in `AppLogger`'s history, matching that established pattern (mirrors the
/// technique used by
/// `bulk_mark_screen_pretick_load_failure_test.dart` for AUD-onboarding-11).
@Tags(['progress'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart'
    show syncWriteFacadeProvider;

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;

/// Fake content repo used by both tests below. [throwOnScopedContent]
/// governs whether `getScopedContent` (the scoped/per-track load path)
/// throws — `getContentForCurriculum` (the unscoped fallback path) never
/// throws so the calendar-position test can reach a non-zero denominator.
class _FakeContentRepo implements ContentRepository {
  const _FakeContentRepo({this.throwOnScopedContent = false});

  final bool throwOnScopedContent;

  List<ContentItem> _itemsFor(CurriculumId curriculumId) => List.generate(
    3,
    (i) => ContentItem(
      curriculumId: curriculumId.storageKey,
      sefariaRef: '${curriculumId.storageKey}_ref_$i',
      displayNameEn: 'Item $i',
      displayNameHe: 'פריט $i',
      level1: 'Seder',
      level2: 'Masechta',
      level3: null,
      level4: null,
      isLeaf: true,
      sortOrder: i,
    ),
  );

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => _itemsFor(curriculumId);

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta'],
    totalItems: 3,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    if (throwOnScopedContent) {
      throw Exception('AUD-progress-06 test: scoped content load boom');
    }
    return _itemsFor(curriculumId);
  }

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => _profileId;
}

/// Avoids the SharedPreferences plugin dependency of the real
/// hebrewTermsPreferenceProvider (mirrors
/// track_dual_progress_metrics_batch_test.dart).
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

void main() {
  setUp(() {
    // Fresh Talker history per test so assertions don't see breadcrumbs
    // from a previous test in the same run.
    AppLogger.instance.talker.cleanHistory();
  });

  group(
    'AUD-progress-06 — lifetime_knowledge_providers.dart log-less catches',
    () {
      test('_computeTrackDualProgressMetric: a programCalendarPositionProvider '
          'failure is logged via AppLogger before overdueCount/todayDueCount '
          'fall back to 0', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        final trackId = await seedTrack(
          db,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
        );

        // Enrollment must exist so _computeTrackDualProgressMetric enters
        // the calendar-position branch at all.
        await db
            .into(db.profilePrograms)
            .insert(
              ProfileProgramsCompanion.insert(
                profileId: _profileId,
                curriculumType: CurriculumId.mishnayos.storageKey,
                programId: 1,
              ),
            );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(
              const _FakeContentRepo(),
            ),
            activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
            useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
            syncWriteFacadeProvider.overrideWithValue(null),
            // Force the exact failure this finding describes: the
            // downstream calendar-position lookup throws.
            programCalendarPositionProvider(trackId).overrideWith((ref) async {
              throw Exception('AUD-progress-06 test: calendar position boom');
            }),
          ],
        );
        addTearDown(container.dispose);

        final metrics = await container.read(
          trackDualProgressMetricsProvider(_profileId).future,
        );

        final metric = metrics.firstWhere(
          (m) => m.trackId == trackId,
          orElse: () => throw StateError(
            'expected a metric for trackId $trackId — got: $metrics',
          ),
        );

        // The fallback behaviour (0/0) must still hold — this test is about
        // adding the missing breadcrumb, not changing the fallback values.
        expect(metric.overdueCount, 0);
        expect(metric.todayDueCount, 0);

        // Assert on the fixed AppLogger `event` name rather than the raw
        // exception text: Riverpod's autoDispose lifecycle can replace a
        // synchronously-injected test exception with its own internal
        // "disposed during loading" error by the time it reaches the catch
        // block (a test-harness artifact, not something the fix controls).
        // What matters — and what the finding is about — is that the catch
        // block calls AppLogger at all, with a stable, greppable event name.
        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any(
            (m) => m.contains('track_dual_progress_calendar_position_failed'),
          ),
          isTrue,
          reason:
              'Expected the swallowed programCalendarPositionProvider '
              'failure to be logged via AppLogger instead of the catch '
              'block silently defaulting overdueCount/todayDueCount to 0 '
              'with no diagnostic trail (AUD-progress-06). '
              'Talker history: $history',
        );
      });

      test(
        '_safeLoadLeavesForTrack: a getScopedContent failure is logged via '
        'AppLogger before the track is dropped from the result list',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);
          final trackId = await seedTrack(
            db,
            profileId: _profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
          );

          // A non-empty scope row for this track routes
          // _safeLoadLeavesForTrack through repo.getScopedContent (the
          // branch that throws below) instead of the unscoped fallback.
          await db
              .into(db.curriculumScopes)
              .insert(
                CurriculumScopesCompanion.insert(
                  profileId: _profileId,
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  trackId: trackId,
                  scopeLevel: 1,
                  scopeValue: 'Seder Zeraim',
                  createdAt: DateTime.utc(2026, 1, 1),
                ),
              );

          final container = ProviderContainer(
            overrides: [
              userDatabaseProvider.overrideWith((ref) => db),
              contentRepositoryProvider.overrideWithValue(
                const _FakeContentRepo(throwOnScopedContent: true),
              ),
              activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
              useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
              syncWriteFacadeProvider.overrideWithValue(null),
            ],
          );
          addTearDown(container.dispose);

          final metrics = await container.read(
            trackDualProgressMetricsProvider(_profileId).future,
          );

          // The fallback behaviour (track dropped from the list) must still
          // hold — this test is about adding the missing breadcrumb, not
          // changing the skip behaviour.
          expect(
            metrics.any((m) => m.trackId == trackId),
            isFalse,
            reason:
                'the track must still be skipped on a scoped-content load '
                'failure — the fix only adds logging, not new fallback logic',
          );

          final history = AppLogger.instance.talker.history
              .map((e) => e.generateTextMessage())
              .toList();
          expect(
            history.any(
              (m) =>
                  m.contains(
                    'AUD-progress-06 test: scoped content load boom',
                  ) ||
                  m.contains('lifetime_safe_load_failed'),
            ),
            isTrue,
            reason:
                'Expected the swallowed getScopedContent failure inside '
                '_safeLoadLeavesForTrack to be logged via AppLogger instead '
                'of the catch block silently dropping the track with no '
                'diagnostic trail (AUD-progress-06). Talker history: $history',
          );
        },
      );
    },
  );
}
