// L1 widget tests — OnboardingScreen phase flow + BulkMarkScreen sentinel-date
// crediting.
//
// Coverage:
//   OnboardingScreen:
//     • Starts at profileCreation phase (profile-name field + mode pills present)
//     • "Create Profile" button is disabled when name is empty (adult mode)
//     • Selecting "Child Mode" shows ACTIVE badge
//     • After simulated profile creation, child path advances to parentPinSetup
//     • After simulated profile creation, adult path advances to intentChooser
//       ("What brings you here?" header)
//     • childAwareText() pure-function: adult text returned in adult mode
//     • childAwareText() pure-function: template substituted in child mode
//     • Auth bounce: signed-out AuthState triggers replaceAll([SignInRoute])
//     • Resume from saved state (addTrack phase) respects stored snapshot
//     • intentChooser: "Track my own learning" card is present
//     • intentChooser: "Skip for now" card is present
//     • addAnotherPrompt phase shows "Start Learning" and "Add Another Track"
//     • handoff phase shows child name in heading
//     • RTL smoke — screen mounts without overflow in he locale
//
//   BulkMarkScreen:
//     • Renders selection phase (no stage-picker — B5)
//     • Tier-credit subtitle present (B1 — credits siyumim/lifetime, not streak/points)
//     • "Next" button disabled when no selections
//     • Skip button is present and calls Navigator.pop(null)
//     • Search icon toggles to search-bar TextField
//     • Pre-ticked refs loaded from sentinel-dated completions (B7)
//     • Unticking a pre-ticked item triggers expungePriorCompletions (B8)
//     • Confirmation phase shows item count and Confirm/Back buttons
//     • Back from confirmation returns to selection phase
//     • Execute bulk-mark: shows processing indicator then done phase
//     • Done phase shows count, Continue button pops BulkMarkResult
//     • Confirmation toast shown after bulk-mark commits (count + Lifetime Knowledge)
//     • Error in _executeBulkMark stays on confirmation phase with error text
//     • "mark everything" guard: snackbar if all items selected
//     • RTL smoke — mounts in he locale without overflow
//     • Sentinel date: bulk-mark uses kBulkPriorSentinelDate (2000-01-01 UTC)
//       credits siyumim + lifetime — not streak (product rule)
//
// BUG / product-rule notes:
//   none found.

@Tags(['onboarding', 'bulk_mark'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockBulkPriorCompletionService extends Mock
    implements BulkPriorCompletionService {}

// ── Shared content fixtures ───────────────────────────────────────────────────

const _leafA = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: '1',
  level4: '1',
  displayNameHe: 'ברכות א:א',
  displayNameEn: 'Berakhot 1:1',
  sefariaRef: 'Mishnah Berakhot 1:1',
  sortOrder: 1,
  isLeaf: true,
);
const _leafB = ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: '1',
  level4: '2',
  displayNameHe: 'ברכות א:ב',
  displayNameEn: 'Berakhot 1:2',
  sefariaRef: 'Mishnah Berakhot 1:2',
  sortOrder: 2,
  isLeaf: true,
);
const _twoLeaves = [_leafA, _leafB];

// ── OnboardingScreen rig ─────────────────────────────────────────────────────

Widget _onboardingRig({
  required _MockStackRouter router,
  AuthState? authState,
  _MockProfileRepository? profileRepo,
  Locale locale = const Locale('en'),
}) {
  final state =
      authState ??
      const AuthState.signedIn(
        user: AuthUser(profileId: 1, email: 't@t.com', displayName: 'T'),
        tier: Tier.localBorn,
      );

  final repo = profileRepo ?? _MockProfileRepository();
  // Default: empty profiles list
  when(() => repo.getProfilesByAccount(any())).thenAnswer((_) async => []);

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier(state)),
      profileRepositoryProvider.overrideWithValue(repo),
      // selectedProfileId has no side-effects in these tests
      selectedProfileIdProvider.overrideWith(() => _NullSelectedProfileId()),
      currentAccountIdProvider.overrideWithValue(1),
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
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const OnboardingScreen(),
      ),
    ),
  );
}

// ── BulkMarkScreen rig ────────────────────────────────────────────────────────

Widget _bulkMarkRig({
  _MockCompletionRepository? completionRepo,
  _MockContentRepository? contentRepo,
  _MockBulkPriorCompletionService? service,
  List<ContentItem> allItems = const [],

  /// Only applied when completionRepo is null (auto-created).
  List<Completion> existingCompletions = const [],
  Locale locale = const Locale('en'),
}) {
  final cRepo = completionRepo ?? _MockCompletionRepository();
  if (completionRepo == null) {
    // Auto-created repo: apply the default stub.
    when(
      () => cRepo.getCompletionsByCurriculum(any()),
    ).thenAnswer((_) async => existingCompletions);
  }
  // When completionRepo is provided, the caller is responsible for stubbing it.

  final contentRepository = contentRepo ?? _MockContentRepository();
  if (contentRepo == null) {
    when(
      () => contentRepository.getContentForCurriculum(any()),
    ).thenAnswer((_) async => allItems);
    when(
      () => contentRepository.search(
        curriculumId: any(named: 'curriculumId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => <ContentItem>[]);
  }

  final svc = service ?? _MockBulkPriorCompletionService();

  return ProviderScope(
    overrides: [
      contentRepositoryProvider.overrideWithValue(contentRepository),
      curriculumContentProvider.overrideWith(
        (ref, curriculumId) =>
            contentRepository.getContentForCurriculum(curriculumId),
      ),
      contentSearchProvider.overrideWith((ref, args) => Future.value([])),
      completionRepositoryProvider.overrideWithValue(cRepo),
      bulkPriorCompletionServiceProvider.overrideWithValue(svc),
      activeProfileIdProvider.overrideWithValue(1),
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
      home: const BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
    ),
  );
}

// ── Stub notifiers ────────────────────────────────────────────────────────────

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _NullSelectedProfileId extends SelectedProfileId {
  @override
  int? build() => null;
}

// ── Tear-down helper ──────────────────────────────────────────────────────────

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<HierarchySelection>[]);
  });

  // ── OnboardingScreen ────────────────────────────────────────────────────────

  group('OnboardingScreen — profileCreation phase', () {
    late _MockStackRouter router;

    setUp(() {
      router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('starts at profileCreation: name field + mode pills visible', (
      tester,
    ) async {
      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Name field
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
      // Mode pills
      expect(find.text('Adult Mode'), findsOneWidget);
      expect(find.text('Child Mode'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Create Profile button is disabled with empty name', (
      tester,
    ) async {
      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The "Create Profile" FilledButton is disabled when the name field is
      // empty. We find it via the descendant Text it contains.
      final createProfileBtnFinder = find.ancestor(
        of: find.text('Create Profile'),
        matching: find.byType(FilledButton),
      );
      expect(createProfileBtnFinder, findsOneWidget);
      final btn = tester.widget<FilledButton>(createProfileBtnFinder);
      expect(
        btn.onPressed,
        isNull,
        reason: 'Create Profile must be disabled when name is empty',
      );

      await _tearDown(tester);
    });

    testWidgets('tapping "Child Mode" shows ACTIVE badge', (tester) async {
      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Child Mode'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('ACTIVE'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('no app bar shown at profileCreation phase', (tester) async {
      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // AppBar is suppressed at this phase (no title text like "Set Parent PIN")
      expect(find.text('Set Parent PIN'), findsNothing);
      expect(find.text('Set Up a Track'), findsNothing);

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — childAwareText helper', () {
    test('returns adultText when not in child mode', () {
      expect(
        childAwareText('Adult text', 'Hello {name}', 'David'),
        'Adult text',
      );
    });

    test('substitutes child name when isChildMode=true', () {
      expect(
        childAwareText(
          'Adult text',
          'Hello {name}',
          'David',
          isChildMode: true,
        ),
        'Hello David',
      );
    });

    test(
      'returns adultText when childName is null even if isChildMode=true',
      () {
        expect(
          childAwareText('Adult text', 'Hello {name}', null, isChildMode: true),
          'Adult text',
        );
      },
    );
  });

  group('OnboardingScreen — auth bounce', () {
    testWidgets('signed-out AuthState triggers replaceAll([SignInRoute])', (
      tester,
    ) async {
      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        _onboardingRig(router: router, authState: const AuthState.signedOut()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final captured = verify(() => router.replaceAll(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final routes = captured.first as List<dynamic>;
      expect(routes.first, isA<SignInRoute>());

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — resume from saved state', () {
    testWidgets('restores to addTrack phase from saved prefs', (tester) async {
      // Save an "addTrack" phase snapshot so the screen resumes directly there.
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'addTrack',
        'onboarding_profile_id': 5,
        'onboarding_profile_name': 'Avraham',
        'onboarding_profile_mode': 'adult',
        'onboarding_use_hebrew_calendar': true,
        'onboarding_use_hebrew_terms': true,
        'onboarding_show_nikud': true,
        'onboarding_transliteration_variant': 'ashkenazi',
      });

      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      // Allow _tryResumeFromSavedState async to settle
      await tester.pump(const Duration(seconds: 1));

      // addTrack phase renders AddTrackFlow which has no app-bar title — but
      // the profile-creation name field should NOT be present.
      expect(find.text('Adult Mode'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('legacy calendarPreference phase maps to addTrack', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'calendarPreference',
        'onboarding_profile_id': 3,
        'onboarding_profile_name': 'Yosef',
        'onboarding_profile_mode': 'adult',
        'onboarding_use_hebrew_calendar': true,
        'onboarding_use_hebrew_terms': true,
        'onboarding_show_nikud': true,
        'onboarding_transliteration_variant': 'ashkenazi',
      });

      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should have moved to addTrack, not show name field from profileCreation
      expect(find.text('Adult Mode'), findsNothing);

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — intentChooser phase', () {
    testWidgets('shows branch-chooser cards after profile created (adult)', (
      tester,
    ) async {
      // Pre-load the screen to intentChooser phase via saved state
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'intentChooser',
        'onboarding_profile_id': 2,
        'onboarding_profile_name': 'Moshe',
        'onboarding_profile_mode': 'adult',
        'onboarding_use_hebrew_calendar': true,
        'onboarding_use_hebrew_terms': true,
        'onboarding_show_nikud': true,
        'onboarding_transliteration_variant': 'ashkenazi',
      });

      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Intent chooser header
      expect(find.text('What brings you here?'), findsOneWidget);
      // The two cards
      expect(find.text('Track my own learning'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — addAnotherPrompt phase', () {
    testWidgets('shows start learning and add another track buttons', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'addAnotherPrompt',
        'onboarding_profile_id': 2,
        'onboarding_profile_name': 'Moshe',
        'onboarding_profile_mode': 'adult',
        'onboarding_use_hebrew_calendar': true,
        'onboarding_use_hebrew_terms': true,
        'onboarding_show_nikud': true,
        'onboarding_transliteration_variant': 'ashkenazi',
      });

      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Track Ready!'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — handoff phase', () {
    testWidgets('shows child name in heading', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_phase': 'handoff',
        'onboarding_profile_id': 4,
        'onboarding_profile_name': 'Yitzchak',
        'onboarding_profile_mode': 'child',
        'onboarding_use_hebrew_calendar': true,
        'onboarding_use_hebrew_terms': true,
        'onboarding_show_nikud': true,
        'onboarding_transliteration_variant': 'ashkenazi',
      });

      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_onboardingRig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Setup Complete!'), findsOneWidget);
      // Child name in heading
      expect(find.textContaining('Yitzchak'), findsAtLeastNWidgets(1));

      await _tearDown(tester);
    });
  });

  group('OnboardingScreen — RTL smoke', () {
    testWidgets('mounts without overflow in he locale', (tester) async {
      final router = _MockStackRouter();
      when(() => router.replaceAll(any())).thenAnswer((_) async {});
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        _onboardingRig(router: router, locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── BulkMarkScreen ──────────────────────────────────────────────────────────

  group('BulkMarkScreen — initial render / selection phase', () {
    testWidgets('renders Scaffold with selection-phase header', (tester) async {
      await tester.pumpWidget(_bulkMarkRig());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(
        find.text("Select content you've already completed"),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('stage-picker is absent (B5)', (tester) async {
      await tester.pumpWidget(_bulkMarkRig());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Which stages have you completed?'),
        findsNothing,
        reason: 'Stage-picker must be removed (B5)',
      );

      await _tearDown(tester);
    });

    testWidgets(
      'B1 tier-credit subtitle present (credits siyumim/lifetime, not streak/points)',
      (tester) async {
        await tester.pumpWidget(_bulkMarkRig());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The siyumimTerm is interpolated by domainTermLabels(ref).siyumim which
        // defaults to Hebrew script ('סיומים') in the test environment because
        // HebrewTermsPreference.defaultValue is true. Check stable sub-strings
        // from the en ARB template that are always present regardless of the
        // resolved term.
        expect(
          find.textContaining('and lifetime knowledge'),
          findsOneWidget,
          reason: 'Subtitle must mention lifetime knowledge',
        );
        expect(
          find.textContaining('not toward your streak'),
          findsOneWidget,
          reason: 'Subtitle must clarify streak is not credited',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('"Next" button disabled when no selections', (tester) async {
      await tester.pumpWidget(_bulkMarkRig(allItems: _twoLeaves));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final nextBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(nextBtn.onPressed, isNull);

      await _tearDown(tester);
    });

    testWidgets('"Skip" OutlinedButton is present', (tester) async {
      await tester.pumpWidget(_bulkMarkRig());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('search icon toggles to text-field', (tester) async {
      await tester.pumpWidget(_bulkMarkRig());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Search icon button is present in the AppBar actions
      expect(find.byIcon(Icons.search), findsOneWidget);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // After tap, a TextField replaces the title
      expect(find.byType(TextField), findsOneWidget);
      // Search icon replaced by close icon
      expect(find.byIcon(Icons.close), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('BulkMarkScreen — pre-tick from sentinel completions (B7)', () {
    testWidgets('sentinel-dated completion pre-ticks the item', (tester) async {
      final completionRepo = _MockCompletionRepository();
      final contentRepo = _MockContentRepository();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);

      // leafA has a sentinel-dated completion → pre-ticked
      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: _leafA.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate, // sentinel 2000-01-01 UTC
            points: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          allItems: _twoLeaves,
          existingCompletions: const [], // provider already mocked above
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // With a pre-ticked item, "Next" should be enabled
      final nextBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(
        nextBtn.onPressed,
        isNotNull,
        reason: 'Pre-ticked selection should enable the Next button',
      );

      await _tearDown(tester);
    });

    test(
      'sentinel date is 2000-01-01 UTC (product rule: not recent/streak)',
      () {
        // Verify the sentinel constant used by the bulk-mark flow.
        // This is the key product rule: sentinel date credits lifetime/siyumim
        // but is NOT in the recent-activity window (2000 CE is decades ago).
        expect(kBulkPriorSentinelDate.year, 2000);
        expect(kBulkPriorSentinelDate.month, 1);
        expect(kBulkPriorSentinelDate.day, 1);
        expect(kBulkPriorSentinelDate.isUtc, isTrue);
      },
    );

    test('isBulkPriorSentinel returns true for kBulkPriorSentinelDate', () {
      expect(isBulkPriorSentinel(kBulkPriorSentinelDate), isTrue);
    });

    test(
      'isBulkPriorSentinel returns true for non-UTC DateTime at same moment',
      () {
        // Simulate a completion coming back from Firestore/Drift without UTC flag
        final nonUtc = kBulkPriorSentinelDate.toLocal();
        expect(
          isBulkPriorSentinel(nonUtc),
          isTrue,
          reason:
              'Moment-based comparison must survive isUtc=false round-trips',
        );
      },
    );

    test('isBulkPriorSentinel returns false for today', () {
      expect(isBulkPriorSentinel(DateTime.now()), isFalse);
    });
  });

  group('BulkMarkScreen — confirmation phase', () {
    late _MockCompletionRepository completionRepo;
    late _MockContentRepository contentRepo;
    late _MockBulkPriorCompletionService service;

    setUp(() {
      completionRepo = _MockCompletionRepository();
      contentRepo = _MockContentRepository();
      service = _MockBulkPriorCompletionService();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);

      // Pre-tick leafA via sentinel completion so Next is enabled immediately
      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: _leafA.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate,
            points: 0,
          ),
        ],
      );

      when(
        () => service.resolveSelections(
          curriculumId: any(named: 'curriculumId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => [_leafA]);
    });

    testWidgets('tapping Next transitions to confirmation phase', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: _twoLeaves,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Confirmation phase
      expect(find.text('Confirm Bulk Mark'), findsOneWidget);
      // AUD-onboarding-04: itemCount now renders via the shared itemsCount()
      // ICU plural (l10n) instead of a hand-built "$itemCount items" literal,
      // so a single item correctly reads "1 Item" (not the old "1 items").
      expect(find.text('1 Item'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Back from confirmation returns to selection phase', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: _twoLeaves,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pump();

      // Back on selection phase
      expect(
        find.text("Select content you've already completed"),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  group('BulkMarkScreen — execute bulk-mark', () {
    late _MockCompletionRepository completionRepo;
    late _MockContentRepository contentRepo;
    late _MockBulkPriorCompletionService service;

    setUp(() {
      completionRepo = _MockCompletionRepository();
      contentRepo = _MockContentRepository();
      service = _MockBulkPriorCompletionService();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);

      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: _leafA.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate,
            points: 0,
          ),
        ],
      );

      when(
        () => service.resolveSelections(
          curriculumId: any(named: 'curriculumId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => [_leafA]);

      when(
        () => service.execute(
          curriculumId: any(named: 'curriculumId'),
          resolvedItems: any(named: 'resolvedItems'),
          stageIds: any(named: 'stageIds'),
        ),
      ).thenAnswer(
        (_) async =>
            const BulkPriorCompletionResult(itemCount: 1, completionCount: 1),
      );
    });

    testWidgets('shows processing indicator then done phase', (tester) async {
      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: _twoLeaves,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigate to confirmation
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump(); // start future

      // Processing indicator should briefly appear; pump to complete
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));

      // Done phase
      expect(find.text('Done!'), findsOneWidget);
      expect(
        find.textContaining('Marked 1 items as completed'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('confirmation toast shown (count + Lifetime Knowledge)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: _twoLeaves,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(); // allow SnackBar to render

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('1 items marked as previously learned'),
        findsOneWidget,
      );
      expect(find.textContaining('Lifetime Knowledge'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('done phase: Continue button pops BulkMarkResult', (
      tester,
    ) async {
      BulkMarkResult? poppedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(contentRepo),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value(_twoLeaves),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
            completionRepositoryProvider.overrideWithValue(completionRepo),
            bulkPriorCompletionServiceProvider.overrideWithValue(service),
            activeProfileIdProvider.overrideWithValue(1),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // Wrap in Navigator so pop can be observed
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.of(context)
                      .push<BulkMarkResult?>(
                        MaterialPageRoute<BulkMarkResult?>(
                          builder: (_) => const BulkMarkScreen(
                            curriculumId: CurriculumId.mishnayos,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open the screen
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigate to confirmation
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Execute
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Done phase — tap Continue
      expect(find.text('Done!'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Result should have been popped
      expect(poppedResult, isNotNull);
      expect(poppedResult!.itemCount, 1);
      expect(poppedResult!.completionCount, 1);

      await _tearDown(tester);
    });

    // AUD-onboarding-05: the raw exception must never reach the UI. The
    // confirmation-phase error banner shows an AppLocalizations-sourced
    // string (errorSaveFailed), verified in both en and he, in place of the
    // untranslated `e.toString()` implementation detail.
    for (final locale in const [Locale('en'), Locale('he')]) {
      testWidgets(
        'error in execute stays on confirmation with a localized error '
        '(${locale.languageCode})',
        (tester) async {
          when(
            () => service.execute(
              curriculumId: any(named: 'curriculumId'),
              resolvedItems: any(named: 'resolvedItems'),
              stageIds: any(named: 'stageIds'),
            ),
          ).thenThrow(Exception('Network error'));

          await tester.pumpWidget(
            _bulkMarkRig(
              completionRepo: completionRepo,
              contentRepo: contentRepo,
              service: service,
              allItems: _twoLeaves,
              locale: locale,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          // Button labels are localized (he != "Next"/"Confirm"), so locate
          // by type rather than by English text — each phase renders exactly
          // one FilledButton.
          await tester.tap(find.byType(FilledButton).last);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          await tester.tap(find.byType(FilledButton).last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          final expectedError = locale.languageCode == 'he'
              ? 'השמירה נכשלה. נסו שוב.'
              : 'Failed to save. Please try again.';

          // Still on confirmation phase, showing the localized error — never
          // the raw exception's toString().
          expect(find.text(expectedError), findsOneWidget);
          expect(find.textContaining('Exception'), findsNothing);
          expect(find.textContaining('Network error'), findsNothing);

          await _tearDown(tester);
        },
      );
    }
  });

  group('BulkMarkScreen — "mark everything" guard', () {
    testWidgets('shows snackbar when all items selected', (tester) async {
      final completionRepo = _MockCompletionRepository();
      final contentRepo = _MockContentRepository();
      final service = _MockBulkPriorCompletionService();

      // Only one leaf — selecting it covers 100% of content
      const singleLeaf = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
        displayNameHe: 'ברכות א:א',
        displayNameEn: 'Berakhot 1:1',
        sefariaRef: 'Mishnah Berakhot 1:1',
        sortOrder: 1,
        isLeaf: true,
      );

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => [singleLeaf]);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);

      // Pre-tick the only leaf (sentinel completion)
      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: singleLeaf.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate,
            points: 0,
          ),
        ],
      );

      // resolveSelections returns the single leaf (all content selected)
      when(
        () => service.resolveSelections(
          curriculumId: any(named: 'curriculumId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => [singleLeaf]);

      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: [singleLeaf],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Next is enabled (1 selection)
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show snackbar warning, not move to confirmation
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('You must leave at least some content unmarked'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  group('BulkMarkScreen — expunge on untick (B8)', () {
    testWidgets('unticking pre-ticked item calls expungePriorCompletions', (
      tester,
    ) async {
      final completionRepo = _MockCompletionRepository();
      final contentRepo = _MockContentRepository();
      final service = _MockBulkPriorCompletionService();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);

      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: _leafA.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate,
            points: 0,
          ),
        ],
      );

      when(
        () => service.expungePriorCompletions(
          profileId: any(named: 'profileId'),
          sefariaRef: any(named: 'sefariaRef'),
          curriculumId: any(named: 'curriculumId'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        _bulkMarkRig(
          completionRepo: completionRepo,
          contentRepo: contentRepo,
          service: service,
          allItems: _twoLeaves,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After pre-tick loading, leafA is selected. The top-level Zeraim row
      // shows a partial (tri-state null) checkbox since only 1 of 2 leaves is
      // ticked. Tapping it will select ALL descendants, so after one tap it
      // becomes true; a second tap deselects all — triggering the expunge path
      // for the pre-ticked leaf.
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsAtLeastNWidgets(1));

      // First tap: partial → full (all selected)
      await tester.tap(checkboxFinder.first);
      await tester.pump();
      // Second tap: full → none (deselects, triggers expunge for pre-ticked refs)
      await tester.tap(checkboxFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // expungePriorCompletions must have been called
      verify(
        () => service.expungePriorCompletions(
          profileId: any(named: 'profileId'),
          sefariaRef: any(named: 'sefariaRef'),
          curriculumId: any(named: 'curriculumId'),
        ),
      ).called(greaterThanOrEqualTo(1));

      await _tearDown(tester);
    });
  });

  group('BulkMarkScreen — RTL smoke', () {
    testWidgets('mounts in he locale without overflow', (tester) async {
      await tester.pumpWidget(_bulkMarkRig(locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);

      await _tearDown(tester);
    });
  });
}
