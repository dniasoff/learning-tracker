/// Bulk-mark reactivity staleness (Release Reassurance R5 follow-up).
///
/// R5 (`test/helpers/reactivity_contract.dart`) built a shared
/// `expectRebuildsOn()` guard and adopted it onto 7 providers, but the
/// bulk-mark-prior entry point was never checked against it. Two call sites
/// still hand-picked a short list of providers to `ref.invalidate(...)`
/// instead of firing the same `completionCommittedProvider` signal the live
/// mark path (`text_display_screen.dart`) uses:
///   - `BulkMarkScreen._executeBulkMark()`
///   - `BulkMarkScreen._expungeRefs()`
/// The hand-picked list missed `lifetimeTotalsAcrossAllCurriculaProvider`,
/// `trackDualProgressMetricsProvider`, and `journeyViewModelProvider` — all
/// three watch `completionCommittedProvider` (directly or transitively) but
/// none were in the list, so a persistently-mounted Dashboard/Progress
/// "Lifetime" tile kept showing its stale pre-bulk-mark value until the next
/// full remount (a pull-to-refresh or navigating away and back).
///
/// ## Why the existing guards did not catch this
///
/// - `lifetime_knowledge_providers_test.dart`'s "D9 — lifetime chain
///   reactivity to completionCommitted" group calls
///   `completionCommittedProvider.notifier.increment()` **manually** to
///   simulate a commit — it proves the PROVIDER reacts to the signal, not
///   that the bulk-mark call site actually FIRES it.
/// - `bulk_mark_all_time_rollup_test.dart` asserts via a fresh
///   `ProviderContainer.read(...)` per test (a cold build) — there is no
///   already-mounted listener to go stale, so a missing signal is invisible.
///
/// This test drives the REAL `BulkMarkScreen` UI (tap the checkbox, tap
/// Next, tap Confirm — the actual `_executeBulkMark()` code path, backed by
/// a real in-memory DB and a real `BulkPriorCompletionService`) while an
/// already-established listener on `lifetimeTotalsAcrossAllCurriculaProvider`
/// (mirroring a persistently-mounted Dashboard tile) is watching. It never
/// calls `.increment()` itself — only the production code under test may.
///
/// `bulkPriorCompletionServiceProvider`'s default Riverpod wiring pulls in
/// `bookmarkRepositoryProvider` -> `FirestoreBookmarkRepositoryAdapter` ->
/// `firestoreBookmarkRepositoryProvider` -> real Firebase Auth/Firestore
/// account resolution (still `[core/no-app] No Firebase App '[DEFAULT]'`
/// in a plain widget test — bookmarks moved onto a different provider
/// chain than the old `firestoreGatewayProvider` one, but it still needs a
/// real signed-in Firebase app) — every existing `BulkMarkScreen` test
/// avoids this the same way (`bulk_mark_screen_test.dart`,
/// `bulk_mark_screen_expunge_ordering_test.dart`): override
/// `completionRepositoryProvider`/`bulkPriorCompletionServiceProvider`
/// directly instead of letting the real provider graph resolve. Those two
/// sibling tests get away with a canned `_MockBulkPriorCompletionService`
/// because they never assert on real completion-write side effects; this
/// test needs the actual completion-write SQL to run — that is what makes
/// `lifetimeTotalsAcrossAllCurriculaProvider` change — so it constructs a
/// REAL `CompletionRepositoryImpl` (`syncEngine: null`, the same wiring
/// `completionRepositoryProvider` gives a local-born/offline account)
/// backed by the real in-memory DB, rather than a mock.
///
/// `BulkPriorCompletionService.execute()` also calls
/// `_bookmarkRepository.setBookmark(...)`, so the service still needs some
/// working `BookmarkRepository`. Bookmarks are Firestore-only now for
/// every account — local-born or not, `bookmarkRepositoryProvider` no
/// longer has a Drift branch — so there is no "the app's own wiring"
/// version of this dependency left to reuse the way there is for
/// completions. The Drift-backed `BookmarkRepositoryImpl` class is still
/// real, working code — just unreachable from the bookmark providers, not
/// deleted — so this test constructs it directly against the same
/// in-memory `db` as a Firebase-free stand-in: real SQL runs, but this is
/// no longer the path production traffic takes.
@Tags(['onboarding', 'bulk_mark', 'riverpod', 'contract'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/reactivity_contract.dart';

const _profileId = 1;
const _curriculumKey = 'mishnayos';
const _curriculum = CurriculumId.mishnayos;
const _sefariaRef = 'Mishnah Berakhot 1:1';
const _sefariaRefB = 'Mishnah Shabbat 1:1';

/// Two-leaf content fixture, in two DIFFERENT sedarim (`level1`) — mirrors
/// `reactivity_contract_adoption_test.dart`'s `_FakeContentRepository`, but
/// two leaves rather than one: `_proceedToConfirmation()` rejects a
/// selection that would mark 100% of the curriculum's leaves
/// (`bulkMarkCannotUnmarkAllError`), so a single-leaf fixture can never
/// reach the confirmation step. Two leaves under two different sedarim
/// means the selection panel's top level renders two separate rows/
/// checkboxes, and selecting just one leaves the other genuinely unmarked.
/// `lifetimeTotalsAcrossAllCurriculaProvider` loops every `CurriculumId`, so
/// every curriculum must answer (empty, except mishnayos).
class _TwoLeafContentRepository implements ContentRepository {
  static const _items = [
    ContentItem(
      curriculumId: _curriculumKey,
      sefariaRef: _sefariaRef,
      displayNameEn: _sefariaRef,
      displayNameHe: 'משנה ברכות א:א',
      level1: 'Zeraim',
      level2: 'Berakhot',
      isLeaf: true,
      sortOrder: 0,
    ),
    ContentItem(
      curriculumId: _curriculumKey,
      sefariaRef: _sefariaRefB,
      displayNameEn: _sefariaRefB,
      displayNameHe: 'משנה שבת א:א',
      level1: 'Moed',
      level2: 'Shabbat',
      isLeaf: true,
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => curriculumId == _curriculum ? _items : const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta'],
    totalItems: _items.length,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => curriculumId == _curriculum ? _items : const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => curriculumId == _curriculum ? _items : const [];

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

void main() {
  testWidgets('BulkMarkScreen._executeBulkMark rebuilds an already-mounted '
      'lifetimeTotalsAcrossAllCurriculaProvider listener without the test '
      'ever ticking completionCommittedProvider itself (bulk-mark staleness '
      'regression)', (tester) async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    await seedTrack(db, profileId: _profileId, curriculumId: _curriculumKey);

    final contentRepo = _TwoLeafContentRepository();

    // completionRepo mirrors production wiring for a local-born (offline)
    // account (`syncEngine: null`, same as `completionRepositoryProvider`).
    // bookmarkRepo has no such production equivalent to mirror anymore —
    // bookmarks are Firestore-only now — so it's a deliberate Firebase-free
    // stand-in instead: still real, DB-backed code (not a canned mock),
    // just not what the app itself calls for bookmarks today.
    final bookmarkRepo = BookmarkRepositoryImpl(
      database: db,
      syncEngine: null,
      contentRepository: contentRepo,
      profileId: _profileId,
    );
    final completionRepo = CompletionRepositoryImpl(
      database: db,
      activeProfileId: _profileId,
    );
    final bulkService = BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
      database: db,
    );

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWith((ref) => db),
        contentRepositoryProvider.overrideWithValue(contentRepo),
        curriculumContentProvider.overrideWith(
          (ref, curriculumId) =>
              contentRepo.getContentForCurriculum(curriculumId),
        ),
        contentSearchProvider.overrideWith((ref, args) => Future.value([])),
        activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
        syncWriteFacadeProvider.overrideWithValue(null),
        bulkPriorCompletionServiceProvider.overrideWithValue(bulkService),
        // BulkMarkScreen._loadPreExistingCompletions reads
        // completionRepositoryProvider directly (not only via
        // bulkPriorCompletionServiceProvider) to pre-tick already-completed
        // leaves — same Firebase-avoidance reason as above.
        completionRepositoryProvider.overrideWithValue(completionRepo),
      ],
    );
    addTearDown(container.dispose);

    await expectRebuildsOn(
      container,
      lifetimeTotalsAcrossAllCurriculaProvider(_profileId),
      () async {
        await tester.pumpWidget(
          pumpApp(
            container: container,
            child: const BulkMarkScreen(curriculumId: _curriculum),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Select ONE of the two leaves (leaving the other genuinely
        // unmarked, satisfying _proceedToConfirmation()'s
        // cannot-mark-everything guard).
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();

        // Selection -> confirmation (real _proceedToConfirmation()).
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Confirmation -> processing -> done. This is the REAL
        // _executeBulkMark() call — the production code path under test.
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
      reason:
          'BulkMarkScreen._executeBulkMark must signal '
          'completionCommittedProvider (not just its old hand-picked '
          'ref.invalidate(...) list) so persistently-mounted Lifetime '
          'tiles — lifetimeTotalsAcrossAllCurriculaProvider here, also '
          'trackDualProgressMetricsProvider and journeyViewModelProvider — '
          'update live instead of staying stuck at their pre-bulk-mark '
          'value until the next full remount',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
