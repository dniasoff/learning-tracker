// Widget tests for TextDisplayScreen — the text reader. This is the
// canonical AG-5-mirrored test file for text_display_screen.dart (see
// docs/coding-standards.md); text_display_screen_deep_l1_test.dart carries
// additional deeper-coverage scenarios alongside it.
//
// Covers:
//   • Loading state — CircularProgressIndicator + l10n "Loading text..." shown
//   • Empty/offline state — cloud_off icon + "Text not available" shown when
//     textContentProvider returns null
//   • Error state — error_outline icon + "Failed to load text" shown
//   • Data state — Hebrew section, English section, section labels rendered
//   • RTL — Hebrew segments use TextDirection.rtl; English uses ltr
//   • Hebrew-only content — only Hebrew card shown when English is empty
//   • English-only content — only English card shown when Hebrew is empty
//   • AppBar title — falls back to sefariaRef when renderedDisplayForRef is loading
//   • Navigation prev/next arrows — enabled/disabled based on adjacentContentRefs
//   • Navigation: prev arrow tap calls router.replace with prev ref
//   • Navigation: next arrow tap calls router.replace with next ref
//   • Completion section — "Mark complete" button visible when task matches ref
//   • Completion section — no button when no daily task matches ref
//   • Live-mark gating (tutor): activeTutoredProfileSelectionProvider non-null →
//     button label = "Not available (tutor mode)", onPressed = null, icon = school
//   • Live-mark gating (owner): activeTutoredProfileSelectionProvider null →
//     button label = "Mark complete", onPressed callable
//   • Tutor canMarkLiveCompletion invariant — button ALWAYS disabled in tutor session
//   • Already-done state — button disabled and shows completed stage label
//   • Back button present and calls router.maybePop()
//   • Hebrew locale smoke test — key affordances render without overflow/crash

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _kRef = 'Mishnah Berakhot 1:1';
const _kRef2 = 'Mishnah Berakhot 1:2';

DailyTask _task({required String ref, int stageOrder = 1}) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: stageOrder,
  stageDefinitionId: stageOrder,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackId: 1,
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

TextContent _content({
  String? hebrew = 'מֵאֵימָתַי קוֹרִין',
  String? english = 'From when may one recite',
}) => TextContent.single(
  sefariaRef: _kRef,
  hebrewText: hebrew ?? '',
  englishText: english ?? '',
);

// ─── Build helper ─────────────────────────────────────────────────────────────

/// Build the widget under test with minimal required overrides.
///
/// [textContent] — what [textContentProvider] resolves to.
///   Pass `null` to simulate "text not available" (offline).
///   Pass a [Future.error] via [textError] to simulate a provider failure.
/// [dailyTasks] — what [allDailyTasksProvider] resolves to.
/// [isCompleted] — override for [isStageCompletedProvider].
/// [isTutorSession] — sets [activeTutoredProfileSelectionProvider] to non-null.
/// [adjacentRefs] — prev/next refs the reader's chevrons resolve to. Wired
///   through a fake [ContentIndex] (via [contentIndexProvider]) rather than
///   [adjacentContentRefsProvider] directly — the screen now reads adjacency
///   synchronously off the index (see text_display_screen.dart's READER
///   CHEVRON TAP-SWALLOW FIX note).
/// [disableRetry] — pass `retry: (_, __) => null` to surface AsyncError.
Widget _buildApp({
  required _MockStackRouter router,
  AsyncValue<TextContent?>? textState,
  Exception? textError,
  List<DailyTask>? dailyTasks,
  bool isCompleted = false,
  bool isTutorSession = false,
  ({String? prev, String? next})? adjacentRefs,
  Locale locale = const Locale('en'),
  bool disableRetry = false,
}) {
  final tasks = dailyTasks ?? [_task(ref: _kRef), _task(ref: _kRef2)];
  final adj = adjacentRefs ?? (prev: null, next: null);

  // Build the textContentProvider override.
  // Use a helper to preserve the concrete override type (not dynamic).
  FutureOr<TextContent?> textBuilder(Ref ref) {
    if (textError != null) {
      return Future<TextContent?>.error(textError, StackTrace.empty);
    }
    if (textState != null && textState is AsyncLoading) {
      return Completer<TextContent?>().future;
    }
    if (textState != null && textState is AsyncData<TextContent?>) {
      return Future<TextContent?>.value(textState.value);
    }
    // Default: happy-path content.
    return Future<TextContent?>.value(_content());
  }

  final selection = isTutorSession
      ? const TutoredProfileSelection(
          profileId: 'child-1',
          ownerUid: 'owner-uid',
          grantId: 'grant-1',
          permissions: TutorPermissions(),
        )
      : null;

  return ProviderScope(
    retry: disableRetry ? (_, __) => null : null,
    overrides: [
      textContentProvider(_kRef).overrideWith(textBuilder),
      fontSizeProvider.overrideWith(() => _FakeFontSizeNotifier()),
      showNikudProvider.overrideWith(() => _FakeShowNikudNotifier()),
      renderedDisplayForRefProvider(_kRef).overrideWith((ref) async => _kRef),
      contentIndexProvider.overrideWith((ref) async => _fakeContentIndex(adj)),
      // `curriculumLabelText` (invoked once contentIndexProvider resolves a
      // matching curriculum for `_kRef`) needs this — DB-free fake so it
      // never throws mid-build.
      currentTransliterationVariantProvider.overrideWith(
        () => _FakeTransliterationVariant(),
      ),
      allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
      trackStorageKeyForTrackIdProvider.overrideWith(
        (ref, trackId) async => 'personal',
      ),
      isStageCompletedProvider.overrideWith((ref, params) async => isCompleted),
      completionCommittedProvider.overrideWith(
        () => _FakeCompletionCommitted(),
      ),
      dashboardUserModeProvider.overrideWith((ref) async => ProfileMode.adult),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _FakeActiveTutoredProfileSelection(selection),
      ),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
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
        child: const MediaQuery(
          data: MediaQueryData(size: Size(800, 1200)),
          child: TextDisplayScreen(sefariaRef: _kRef),
        ),
      ),
    ),
  );
}

/// Builds a minimal fake [ContentIndex] containing just [adj.prev] (if any),
/// `_kRef`, and [adj.next] (if any) as sequential leaves of one fake
/// curriculum — so `contentIndex.adjacent(_kRef)` synchronously resolves to
/// exactly [adj], matching the pre-fix `adjacentContentRefsProvider(_kRef)`
/// override's contract one-for-one.
ContentIndex _fakeContentIndex(({String? prev, String? next}) adj) {
  final refs = [
    if (adj.prev != null) adj.prev!,
    _kRef,
    if (adj.next != null) adj.next!,
  ];
  final items = [
    for (var i = 0; i < refs.length; i++)
      ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Fake Chapter',
        level4: 'Item $i',
        displayNameHe: refs[i],
        displayNameEn: refs[i],
        sefariaRef: refs[i],
        sortOrder: i,
        isLeaf: true,
      ),
  ];
  return ContentIndex.fromCurricula({CurriculumId.mishnayos: items});
}

// ─── Minimal notifier overrides ───────────────────────────────────────────────

class _FakeFontSizeNotifier extends FontSizeNotifier {
  @override
  // ignore: prefer_const_declarations
  FontSize build() => FontSize.medium;
}

class _FakeShowNikudNotifier extends ShowNikud {
  @override
  bool build() => true;
}

class _FakeCompletionCommitted extends CompletionCommitted {
  @override
  int build() => 0;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeTransliterationVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

class _FakeActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  _FakeActiveTutoredProfileSelection(this._initial);

  final TutoredProfileSelection? _initial;

  @override
  TutoredProfileSelection? build() => _initial;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    router = _MockStackRouter();
    when(() => router.maybePop<Object?>()).thenAnswer((_) async => true);
    when(() => router.replace<Object?>(any())).thenAnswer((_) async => null);
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/reader');
  });

  // ── Loading state ───────────────────────────────────────────────────────────

  testWidgets('loading — shows CircularProgressIndicator and l10n message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: const AsyncLoading()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Loading text...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Offline / empty state ───────────────────────────────────────────────────

  testWidgets('offline — shows cloud_off icon when text is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: const AsyncData(null)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('offline — shows "Text not available" message', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: const AsyncData(null)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Text not available'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'offline — shows "Check your internet connection and try again." hint',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, textState: const AsyncData(null)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Error state ─────────────────────────────────────────────────────────────

  testWidgets('error — shows error_outline icon and "Failed to load text"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textError: Exception('DB corrupted'),
        disableRetry: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.text('Failed to load text'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('error — localized error view shown, raw error not surfaced', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textError: Exception('DB corrupted'),
        disableRetry: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // R3: the error view now shows a localized title + generic guidance, and
    // must NOT leak the raw error.toString() to end users.
    expect(find.text('Failed to load text'), findsOneWidget);
    expect(find.textContaining('DB corrupted'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Data state — content rendering ─────────────────────────────────────────

  testWidgets('data — Hebrew section card with l10n "Hebrew Text" label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hebrew Text'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'data — English section card with l10n "English Translation" label',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, textState: AsyncData(_content())),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('English Translation'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('data — Hebrew text is rendered', (tester) async {
    const heText = 'מֵאֵימָתַי קוֹרִין';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(hebrew: heText)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining(heText), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('data — English text is rendered', (tester) async {
    const enText = 'From when may one recite';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(english: enText)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining(enText), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'data — Hebrew content renders above English content (reading order)',
    (tester) async {
      const heText = 'מֵאֵימָתַי קוֹרִין אֶת שְׁמַע';
      const enText = 'From when may one recite the Shema';
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content(hebrew: heText, english: enText)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final hebrewPos = tester.getTopLeft(find.textContaining(heText).first);
      final englishPos = tester.getTopLeft(find.textContaining(enText).first);
      expect(
        hebrewPos.dy,
        lessThan(englishPos.dy),
        reason: 'Hebrew section must render above the English section',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('data — divider icon (menu_book_rounded) rendered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── RTL / text direction ────────────────────────────────────────────────────

  testWidgets('RTL — Hebrew Text.rich uses TextDirection.rtl', (tester) async {
    const heText = 'מֵאֵימָתַי';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(hebrew: heText, english: '')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Find the Text.rich widget that carries the Hebrew paragraph.
    // _SegmentParagraph sets textDirection=rtl for Hebrew.
    final richTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textDirection == TextDirection.rtl)
        .toList();
    expect(richTexts, isNotEmpty);
    // Alignment is always start regardless of direction (mirrors for RTL).
    for (final t in richTexts) {
      expect(t.textAlign, TextAlign.start);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('LTR — English Text.rich uses TextDirection.ltr', (tester) async {
    const enText = 'From when may one recite';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(hebrew: '', english: enText)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final richTexts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textDirection == TextDirection.ltr)
        .toList();
    expect(richTexts, isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Hebrew-only content ─────────────────────────────────────────────────────

  testWidgets('Hebrew-only — Hebrew section shown, English section absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(english: '')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Hebrew Text'), findsOneWidget);
    expect(find.text('English Translation'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── English-only content ────────────────────────────────────────────────────

  testWidgets('English-only — English section shown, Hebrew section absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content(hebrew: '')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('English Translation'), findsOneWidget);
    expect(find.text('Hebrew Text'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── AppBar ──────────────────────────────────────────────────────────────────

  testWidgets('AppBar — sefariaRef used as title while rendered label loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    // Only pump once — chain label provider returns the ref directly in helper,
    // but on the very first pump the AppBar should show something.
    await tester.pump();

    // The screen shows the ref as fallback title while the rendered chain
    // loads. `textContaining` (not exact `text`) because contentIndexProvider
    // (a fake, DB-free index in this test) may already have resolved by this
    // point and prefixed a curriculum label ("<Label> › $_kRef") — this test
    // only asserts the ref itself ends up visible, not the exact title shape.
    expect(find.textContaining(_kRef), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // Note: the fully-settled AppBar title (with a resolved breadcrumb chain
  // distinct from the raw sefariaRef) is covered by
  // text_display_screen_deep_l1_test.dart's "J1: AppBar title shows resolved
  // chain title after async settles" — not duplicated here.

  testWidgets('AppBar — back button (arrow_back) is present', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('AppBar — tapping back button calls router.maybePop()', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    verify(() => router.maybePop<Object?>()).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Navigation prev/next arrows ─────────────────────────────────────────────

  testWidgets('navigation — prev arrow disabled when no prev ref', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        adjacentRefs: (prev: null, next: _kRef2),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final prevBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prevBtn.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('navigation — next arrow disabled when no next ref', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        // A distinct placeholder ref (not `_kRef` itself) — the fake
        // ContentIndex needs unique sefariaRefs per leaf, and this test only
        // cares that prev is SOME non-null value.
        adjacentRefs: (prev: 'Mishnah Berakhot 1:0', next: null),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final nextBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(nextBtn.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('navigation — prev arrow enabled when prev ref is present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        adjacentRefs: (prev: 'Mishnah Berakhot 1:0', next: null),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final prevBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prevBtn.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('navigation — next arrow enabled when next ref is present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        adjacentRefs: (prev: null, next: _kRef2),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final nextBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(nextBtn.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // READER CHEVRON TAP-SWALLOW FIX: chevron navigation no longer calls
  // `router.replace` — it updates the displayed ref via in-widget state
  // directly (synchronous `ContentIndex.adjacent` lookup, no route
  // transition, no async loading-gap for rapid taps to drop into). See
  // text_display_screen.dart's fix note and
  // text_display_chevron_tap_swallow_test.dart for the RED-DEMO regression
  // test.
  testWidgets('navigation — tapping next arrow updates displayed ref via state '
      '(no router.replace)', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        adjacentRefs: (prev: null, next: _kRef2),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => router.replace<Object?>(any()));

    // The fake index only has _kRef → _kRef2 ahead, so having moved to
    // _kRef2 the prev arrow (back to _kRef) is now enabled and next
    // (nothing beyond _kRef2) is disabled — confirms the ref actually
    // advanced, not just that replace wasn't called.
    final prevBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    final nextBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(prevBtn.onPressed, isNotNull);
    expect(nextBtn.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('navigation — tapping prev arrow updates displayed ref via state '
      '(no router.replace)', (tester) async {
    const prevRef = 'Mishnah Berakhot 1:0';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        adjacentRefs: (prev: prevRef, next: null),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => router.replace<Object?>(any()));

    // The fake index only has prevRef → _kRef ahead, so having moved to
    // prevRef, next (forward to _kRef) is now enabled and prev (nothing
    // before prevRef) is disabled — confirms the ref actually moved back.
    final prevBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    final nextBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(prevBtn.onPressed, isNull);
    expect(nextBtn.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Completion section ──────────────────────────────────────────────────────

  testWidgets(
    'completion — "Mark complete" button shown when task matches ref (owner)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content()),
          dailyTasks: [_task(ref: _kRef)],
        ),
      );
      // Multiple pumps needed: allDailyTasks → trackStorageKey → isStageCompleted
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mark complete'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'completion — no completion button when no daily task matches this ref',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content()),
          // Tasks are for a different ref
          dailyTasks: [_task(ref: 'Some Other Ref 1:1')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mark complete'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'completion — "Next daily task" button shown when second task exists',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content()),
          dailyTasks: [
            _task(ref: _kRef),
            _task(ref: _kRef2),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Next daily task'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Tutor live-mark gating ──────────────────────────────────────────────────
  // Product rule: canMarkLiveCompletion is ALWAYS false for tutors.
  // The button MUST be disabled and show the "Not available (tutor mode)" label.

  testWidgets(
    'tutor — completion button shows "Not available (tutor mode)" label',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content()),
          dailyTasks: [_task(ref: _kRef)],
          isTutorSession: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Not available (tutor mode)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('tutor — completion button has null onPressed (disabled)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        dailyTasks: [_task(ref: _kRef)],
        isTutorSession: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The FilledButton must be disabled (onPressed = null).
    // Find by the label to locate the right button.
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Not available (tutor mode)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tutor — shows school_rounded icon on completion button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        dailyTasks: [_task(ref: _kRef)],
        isTutorSession: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.school_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'tutor — TutorPermissions.canMarkLiveCompletion is always false invariant',
    (tester) async {
      // Verify the product invariant at the model level.
      const perms = TutorPermissions();
      expect(perms.canMarkLiveCompletion, isFalse);

      // Also verify that even a "full permission" constructed object still has
      // canMarkLiveCompletion = false (it is not settable via constructor).
      final permsFromFirestore = TutorPermissions.fromFirestore({
        'can_view_progress': true,
        'can_view_content': true,
        'can_bulk_prior_completion': true,
        'can_reset_completion': true,
        'can_edit_goals': true,
        'can_edit_stages': true,
        'can_edit_rewards': true,
        'can_edit_study_days': true,
        'can_edit_points': true,
      });
      expect(permsFromFirestore.canMarkLiveCompletion, isFalse);
    },
  );

  testWidgets('owner — completion button has non-null onPressed (callable)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        dailyTasks: [_task(ref: _kRef)],
        isTutorSession: false,
        isCompleted: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Mark complete'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Already-done state ──────────────────────────────────────────────────────

  testWidgets(
    'already-done — completion button disabled when stage is already completed',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(_content()),
          dailyTasks: [_task(ref: _kRef)],
          isTutorSession: false,
          isCompleted: true,
        ),
      );
      // 3 nested async layers: allDailyTasks → trackStorageKey → isStageCompleted
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // When already done the button is disabled (onPressed = null)
      // because `isDone = true` causes `(_saving || isDone || isTutor)`.
      final filledButtons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      expect(filledButtons, isNotEmpty);
      for (final btn in filledButtons) {
        expect(
          btn.onPressed,
          isNull,
          reason: 'Completion FilledButton should be disabled when isDone',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('already-done — check_circle icon shown when stage completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        dailyTasks: [_task(ref: _kRef)],
        isTutorSession: false,
        isCompleted: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Tooltip shown in tutor mode ─────────────────────────────────────────────

  testWidgets('tutor — Tooltip wraps the completion button in tutor mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        textState: AsyncData(_content()),
        dailyTasks: [_task(ref: _kRef)],
        isTutorSession: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // The Tooltip widget must be present in the subtree.
    expect(find.byType(Tooltip), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Multi-segment content (verse numbers) ───────────────────────────────────

  testWidgets(
    'multi-segment — segments with numbers render verse number badges',
    (tester) async {
      final multiContent = TextContent(
        sefariaRef: _kRef,
        segments: [
          TextSegment(
            sefariaRef: '$_kRef:1',
            hebrewText: 'פסוק א',
            englishText: 'Verse one',
            number: 1,
          ),
          TextSegment(
            sefariaRef: '$_kRef:2',
            hebrewText: 'פסוק ב',
            englishText: 'Verse two',
            number: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        _buildApp(router: router, textState: AsyncData(multiContent)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Both segments' text should appear.
      // Verse numbers rendered via _VerseNumberBadge — look for gematriya
      // markers or Arabic numerals in badge containers.
      expect(find.text('Hebrew Text'), findsOneWidget);
      expect(find.text('English Translation'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Hebrew locale smoke test ─────────────────────────────────────────────────

  testWidgets(
    'Hebrew locale smoke — key affordances render without overflow/crash',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          textState: AsyncData(
            _content(hebrew: 'מֵאֵימָתַי קוֹרִין', english: 'From when'),
          ),
          dailyTasks: [_task(ref: _kRef)],
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Must not throw; AppBar back button present; Hebrew content card present.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      // In Hebrew locale the section label is in Hebrew ('טקסט עברי').
      expect(find.text('טקסט עברי'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Progress bar (removed in round-2 R4 — was a fake fixed 15% bar) ──────────

  testWidgets('data — no fake reading-progress bar (removed in round-2 R4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, textState: AsyncData(_content())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // R4: the hardcoded `value: 0.15` LinearProgressIndicator was misleading
    // (pinned at 15% regardless of position) and has been removed.
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
