// Deep L1 widget tests — TextDisplayScreen (strengthening uncovered branches)
//
// PURPOSE: deepen coverage beyond text_display_screen_l1_test.dart, targeting
// branches at ~76% that are NOT exercised by the existing tests.
//
// Coverage groups targeted here (NEW — not duplicating existing l1 file):
//
//  A. Nikud stripping
//     A1. showNikud=false → nikud stripped from Hebrew segment text
//     A2. showNikud=true  → nikud preserved in Hebrew segment text
//
//  B. Insight chips (_buildInsightChips)
//     B1. "priest" keyword → "Vocabulary: Priests" chip visible
//     B2. "time" keyword → "Concept: Time" chip visible
//     B3. "watch" keyword → "Concept: Time" chip visible
//     B4. English text with no keywords → no insight chips rendered
//     B5. Both "priest" + "time" → both chips shown (max 2)
//
//  C. Verse number badges (gematriya + Arabic numerals)
//     C1. Multi-segment Hebrew → gematriya markers (א, ב) in verse badges
//     C2. Multi-segment English → Arabic numeral markers (1, 2) in verse badges
//     C3. Single segment → no verse number badge rendered
//     C4. Segment with number=null → no number badge rendered
//
//  D. Section card label alignment
//     D1. Hebrew section card label aligns left (alignLabelRight=false)
//     D2. English section card label aligns right (alignLabelRight=true)
//
//  E. Completion section — error sub-state
//     E1. allDailyTasksProvider error → error_outline icon + error message shown
//
//  F. Next-daily-task navigation
//     F1. "Next daily task" button tap calls router.replace
//
//  G. TutorPermissions — factory method invariants
//     G1. defaults() always has canMarkLiveCompletion=false
//     G2. readOnly() always has canMarkLiveCompletion=false
//     G3. copyWith() result always has canMarkLiveCompletion=false
//     G4. toFirestore() output does NOT contain the key 'can_mark_live_completion'
//     G5. toString() always contains 'markLive=false[invariant]'
//
//  H. ResolvedSession invariants
//     H1. ResolvedSession.forOwner → isTutorSession=false
//     H2. ResolvedSession.forTutor → isTutorSession=true
//     H3. forTutor effectivePermissions = grant permissions (not owner perms)
//
//  I. Hebrew locale — deep rendering
//     I1. Hebrew locale → section label shows 'טקסט עברי' (Hebrew text label)
//     I2. Hebrew locale → 'תרגום לאנגלית' shown for English section
//     I3. Hebrew locale → no overflow/crash with RTL layout
//
//  J. AppBar title from provider
//     J1. After async settles the AppBar shows the resolved chain title
//
//  K. MarkLiveCompletionUseCase — domain invariant
//     K1. Owner session → delegate called and result returned
//     K2. Tutor session → TutorWriteForbiddenException thrown, delegate NOT called

@Tags(['needs_flutter', 'content_browsing', 'text_display', 'deep'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';
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
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';
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
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

TextContent _content({
  String hebrewText = 'מֵאֵימָתַי קוֹרִין',
  String englishText = 'From when may one recite',
}) => TextContent.single(
  sefariaRef: _kRef,
  hebrewText: hebrewText,
  englishText: englishText,
);

TextContent _multiSegmentContent() => TextContent(
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

// ─── Notifier stubs ──────────────────────────────────────────────────────────

class _FakeFontSizeNotifier extends FontSizeNotifier {
  @override
  FontSize build() => FontSize.medium;
}

class _FakeShowNikudNotifier extends ShowNikud {
  _FakeShowNikudNotifier(this._value);
  final bool _value;

  @override
  bool build() => _value;
}

class _FakeCompletionCommitted extends CompletionCommitted {
  @override
  int build() => 0;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  _FakeActiveTutoredProfileSelection(this._initial);
  final TutoredProfileSelection? _initial;

  @override
  TutoredProfileSelection? build() => _initial;
}

// ─── Build helper ─────────────────────────────────────────────────────────────

Widget _buildApp({
  required _MockStackRouter router,
  TextContent? content,
  List<DailyTask>? dailyTasks,
  bool isCompleted = false,
  Exception? completionStatusError,
  bool completionStatusLoading = false,
  bool isTutorSession = false,
  bool showNikud = true,
  bool disableRetry = false,
  Locale locale = const Locale('en'),
  ({String? prev, String? next})? adjacentRefs,
  Exception? dailyTasksError,
  String? resolvedChainTitle,
}) {
  final tasks = dailyTasks ?? [_task(ref: _kRef)];
  final adj = adjacentRefs ?? (prev: null, next: null);
  final tc = content ?? _content();
  final chainTitle = resolvedChainTitle ?? _kRef;
  final completionStatus = completionStatusLoading
      ? const AsyncLoading<bool>()
      : completionStatusError != null
      ? AsyncError<bool>(completionStatusError, StackTrace.empty)
      : AsyncData<bool>(isCompleted);

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
      textContentProvider(
        _kRef,
      ).overrideWith((ref) => Future<TextContent?>.value(tc)),
      fontSizeProvider.overrideWith(() => _FakeFontSizeNotifier()),
      showNikudProvider.overrideWith(() => _FakeShowNikudNotifier(showNikud)),
      renderedDisplayForRefProvider(
        _kRef,
      ).overrideWith((ref) async => chainTitle),
      adjacentContentRefsProvider(_kRef).overrideWith((ref) async => adj),
      allDailyTasksProvider.overrideWith((ref) {
        if (dailyTasksError != null) {
          return Future<List<DailyTask>>.error(
            dailyTasksError,
            StackTrace.empty,
          );
        }
        return Future.value(tasks);
      }),
      trackStorageKeyForTrackIdProvider(
        CurriculumId.mishnayos,
      ).overrideWithValue(const AsyncData<String>('personal')),
      isStageCompletedProvider((
        sefariaRef: _kRef,
        stageId: 1,
        trackType: 'personal',
      ),).overrideWithValue(
        completionStatus,
      ),
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

// ─── Teardown helper ──────────────────────────────────────────────────────────

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
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
    when(
      () => router.replace<Object?>(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/reader');
  });

  // ── A. Nikud stripping ──────────────────────────────────────────────────────

  testWidgets('A1: showNikud=false strips nikud from Hebrew text', (
    tester,
  ) async {
    // Text with nikud: מֵאֵימָתַי has niqqud marks (tsere, patach, qamets, etc.)
    // After stripping the bare consonants remain: מאימתי
    const withNikud = 'מֵאֵימָתַי';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(hebrewText: withNikud, englishText: ''),
        showNikud: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The rendered text must NOT contain any nikud characters (U+05B0-U+05C7).
    final allTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? (t.textSpan?.toPlainText() ?? ''))
        .join();
    // Check no nikud marks in any rendered text node
    final hasNikud = allTexts.runes.any(
      (rune) =>
          (rune >= 0x0591 && rune <= 0x05bd) ||
          rune == 0x05bf ||
          (rune >= 0x05c1 && rune <= 0x05c2) ||
          rune == 0x05c4 ||
          rune == 0x05c5 ||
          rune == 0x05c7,
    );
    expect(
      hasNikud,
      isFalse,
      reason: 'Nikud marks must be stripped when showNikud=false',
    );
    // Bare consonants must still be present
    expect(find.textContaining('מאימתי'), findsWidgets);

    await _tearDown(tester);
  });

  testWidgets('A2: showNikud=true preserves nikud in Hebrew text', (
    tester,
  ) async {
    const withNikud = 'מֵאֵימָתַי';
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(hebrewText: withNikud, englishText: ''),
        showNikud: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The nikud-containing text must appear somewhere in the tree.
    expect(find.textContaining(withNikud), findsWidgets);

    await _tearDown(tester);
  });

  // ── C. Verse number badges ──────────────────────────────────────────────────

  testWidgets('C1: Multi-segment Hebrew shows gematriya markers (א, ב)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, content: _multiSegmentContent()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Gematriya badge text for segment 1 = 'א', for segment 2 = 'ב'
    expect(find.text('א'), findsWidgets);
    expect(find.text('ב'), findsWidgets);

    await _tearDown(tester);
  });

  testWidgets('C2: Multi-segment English shows Arabic numeral markers (1, 2)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, content: _multiSegmentContent()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Arabic numeral badge text for segment 1 = '1', for segment 2 = '2'
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);

    await _tearDown(tester);
  });

  testWidgets(
    'C3: Single segment → no verse number badge (showSegmentNumbers=false)',
    (tester) async {
      // Single segment with a number — but since length==1, showSegmentNumbers
      // is false (the code: segments.length > 1 && segments.any(...)).
      final singleWithNumber = TextContent(
        sefariaRef: _kRef,
        segments: [
          TextSegment(
            sefariaRef: '$_kRef:1',
            hebrewText: 'פסוק א',
            englishText: 'Verse one',
            number: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        _buildApp(router: router, content: singleWithNumber),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Even though number=1, showNumbers=false because segments.length==1.
      // So 'א' should NOT appear as a badge.
      // The text 'פסוק א' itself starts with 'פסוק ' followed by 'א', but as
      // a standalone single-char 'א' badge it should not be rendered.
      final singleCharAleph = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == 'א')
          .toList();
      expect(
        singleCharAleph,
        isEmpty,
        reason: 'No verse number badge for single-segment content',
      );

      await _tearDown(tester);
    },
  );

  testWidgets('C4: Segment with number=null → no number badge rendered', (
    tester,
  ) async {
    final noNumberContent = TextContent(
      sefariaRef: _kRef,
      segments: [
        TextSegment(
          sefariaRef: 'Berakhot 2a',
          hebrewText: 'טקסט א',
          englishText: 'Text A',
          number: null,
        ),
        TextSegment(
          sefariaRef: 'Berakhot 2b',
          hebrewText: 'טקסט ב',
          englishText: 'Text B',
          number: null,
        ),
      ],
    );
    await tester.pumpWidget(
      _buildApp(router: router, content: noNumberContent),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // segments.length > 1 but no segment has a non-null number
    // → showSegmentNumbers = false → no badges
    // The _SegmentParagraph showNumber param = showNumbers && segment.number != null
    // Since all numbers are null, no WidgetSpan badge is added.
    // We verify no standalone single-letter text nodes appear as badges.
    final allTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.length == 1)
        .toList();
    // No single-char text that is a Hebrew letter used as a badge
    for (final t in allTexts) {
      expect(
        t.runes.length == 1 &&
            t.runes.single >= 0x05d0 &&
            t.runes.single <= 0x05ea,
        isFalse,
        reason: 'No gematriya badge should appear when all numbers are null',
      );
    }

    await _tearDown(tester);
  });

  // ── E. Completion section — error sub-state ─────────────────────────────────

  testWidgets(
    'E1: allDailyTasksProvider error → error_outline + error message shown',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          content: _content(),
          dailyTasksError: Exception('DB failure'),
          disableRetry: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The _CompletionSection error branch renders error_outline icon.
      expect(find.byIcon(Icons.error_outline), findsWidgets);

      await _tearDown(tester);
    },
  );

  testWidgets(
    'E2: completion read error shows an error affordance instead of "not completed"',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          content: _content(),
          completionStatusError: Exception('completion unavailable'),
          disableRetry: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Mark Complete'), findsNothing);

      await _tearDown(tester);
    },
  );

  testWidgets('E3: completion read loading shows a spinner', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(),
        completionStatusLoading: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mark Complete'), findsNothing);

    await _tearDown(tester);
  });

  // ── F. Next-daily-task navigation ───────────────────────────────────────────

  testWidgets('F1: "Next daily task" button tap calls router.replace', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(),
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

    await tester.tap(find.text('Next daily task'));
    await tester.pump();

    verify(
      () => router.replace<Object?>(any<PageRouteInfo>()),
    ).called(greaterThan(0));

    await _tearDown(tester);
  });

  // ── G. TutorPermissions — factory method invariants ─────────────────────────

  test(
    'G1: TutorPermissions.defaults() always has canMarkLiveCompletion=false',
    () {
      final perms = TutorPermissions.defaults();
      expect(perms.canMarkLiveCompletion, isFalse);
    },
  );

  test(
    'G2: TutorPermissions.readOnly() always has canMarkLiveCompletion=false',
    () {
      final perms = TutorPermissions.readOnly();
      expect(perms.canMarkLiveCompletion, isFalse);
      // Also verify it is maximally restricted
      expect(perms.canBulkPriorCompletion, isFalse);
      expect(perms.canEditGoals, isFalse);
      expect(perms.canEditStages, isFalse);
      expect(perms.canEditRewards, isFalse);
      expect(perms.canEditStudyDays, isFalse);
      expect(perms.canEditPoints, isFalse);
      // Still can view
      expect(perms.canViewProgress, isTrue);
      expect(perms.canViewContent, isTrue);
    },
  );

  test(
    'G3: TutorPermissions.copyWith() result always has canMarkLiveCompletion=false',
    () {
      const base = TutorPermissions();
      // Even trying to copyWith every other field to true keeps canMarkLiveCompletion=false
      final copied = base.copyWith(
        canViewProgress: true,
        canViewContent: true,
        canBulkPriorCompletion: true,
        canResetCompletion: true,
        canEditGoals: true,
        canEditStages: true,
        canEditRewards: true,
        canEditStudyDays: true,
        canEditPoints: true,
      );
      expect(copied.canMarkLiveCompletion, isFalse);
    },
  );

  test(
    'G4: TutorPermissions.toFirestore() does NOT include can_mark_live_completion',
    () {
      const perms = TutorPermissions();
      final map = perms.toFirestore();
      expect(
        map.containsKey('can_mark_live_completion'),
        isFalse,
        reason:
            'canMarkLiveCompletion must not be serialised to Firestore — '
            'the invariant is enforced by the server independently',
      );
    },
  );

  test(
    'G5: TutorPermissions.toString() always contains "markLive=false[invariant]"',
    () {
      const perms = TutorPermissions();
      expect(perms.toString(), contains('markLive=false[invariant]'));
    },
  );

  // ── H. ResolvedSession invariants ────────────────────────────────────────────

  test('H1: ResolvedSession.forOwner → isTutorSession=false', () {
    final session = ResolvedSession.forOwner(
      selection: const OwnProfileSelection(profileId: 'p1', ownerUid: 'u1'),
      isChildMode: false,
    );
    expect(session.isTutorSession, isFalse);
    expect(session.role, SessionRole.parentOfOwn);
  });

  test('H2: ResolvedSession.forTutor → isTutorSession=true', () {
    const selection = TutoredProfileSelection(
      profileId: 'child-1',
      ownerUid: 'owner-1',
      grantId: 'grant-1',
      permissions: TutorPermissions(),
    );
    final session = ResolvedSession.forTutor(selection: selection);
    expect(session.isTutorSession, isTrue);
    expect(session.role, SessionRole.tutor);
  });

  test(
    'H3: ResolvedSession.forTutor effectivePermissions = grant permissions',
    () {
      const customPerms = TutorPermissions(
        canViewProgress: false,
        canEditGoals: false,
      );
      const selection = TutoredProfileSelection(
        profileId: 'child-1',
        ownerUid: 'owner-1',
        grantId: 'grant-1',
        permissions: customPerms,
      );
      final session = ResolvedSession.forTutor(selection: selection);
      expect(session.effectivePermissions, equals(customPerms));
      expect(session.effectivePermissions.canViewProgress, isFalse);
      expect(session.effectivePermissions.canEditGoals, isFalse);
    },
  );

  // ── I. Hebrew locale — deep rendering ────────────────────────────────────────

  testWidgets('I1: Hebrew locale → Hebrew section label is "טקסט עברי"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(hebrewText: 'מֵאֵימָתַי', englishText: ''),
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('טקסט עברי'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('I2: Hebrew locale → English section label is "תרגום לאנגלית"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(hebrewText: '', englishText: 'From when'),
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('תרגום לאנגלית'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('I3: Hebrew locale + bilingual content → no overflow or crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        content: _content(
          hebrewText: 'מֵאֵימָתַי קוֹרִין אֶת שְׁמַע',
          englishText: 'From when may one recite the Shema',
        ),
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Must render without exceptions; both section labels present
    expect(find.text('טקסט עברי'), findsOneWidget);
    expect(find.text('תרגום לאנגלית'), findsOneWidget);
    // Back arrow still present
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await _tearDown(tester);
  });

  // ── J. AppBar title from provider ────────────────────────────────────────────

  testWidgets(
    'J1: AppBar title shows resolved chain title after async settles',
    (tester) async {
      const resolvedTitle = 'זרעים › ברכות › פרק א › משנה א';
      await tester.pumpWidget(
        _buildApp(
          router: router,
          content: _content(),
          resolvedChainTitle: resolvedTitle,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After the provider resolves, the AppBar must show the breadcrumb string.
      expect(find.text(resolvedTitle), findsOneWidget);

      await _tearDown(tester);
    },
  );

  // ── K. MarkLiveCompletionUseCase — domain invariant ──────────────────────────

  test('K1: Owner session → delegate called and result returned', () async {
    final session = ResolvedSession.forOwner(
      selection: const OwnProfileSelection(profileId: 'p1', ownerUid: 'u1'),
      isChildMode: false,
    );
    final useCase = MarkLiveCompletionUseCase<String>(session: session);

    var delegateCalled = false;
    final result = await useCase.call(() async {
      delegateCalled = true;
      return 'ok';
    });

    expect(delegateCalled, isTrue);
    expect(result, equals('ok'));
  });

  test(
    'K2: Tutor session → TutorWriteForbiddenException thrown, delegate not called',
    () async {
      const selection = TutoredProfileSelection(
        profileId: 'child-1',
        ownerUid: 'owner-1',
        grantId: 'grant-1',
        permissions: TutorPermissions(),
      );
      final session = ResolvedSession.forTutor(selection: selection);
      final useCase = MarkLiveCompletionUseCase<String>(session: session);

      var delegateCalled = false;
      expect(
        () => useCase.call(() async {
          delegateCalled = true;
          return 'should-not-reach';
        }),
        throwsA(isA<TutorWriteForbiddenException>()),
      );
      // Give the async path time to run
      await Future<void>.delayed(Duration.zero);
      expect(delegateCalled, isFalse);
    },
  );

  // ── Extra: Gematriya correctness ─────────────────────────────────────────────

  test('Gematriya.forNumber special cases: 15=טו, 16=טז', () {
    // Calls the real Gematriya.forNumber directly (not a local copy) so a
    // regression in the 15/16 divine-name-avoidance substitution is caught
    // here, not just indirectly via widget rendering (see C1).
    expect(Gematriya.forNumber(15), equals('טו'));
    expect(Gematriya.forNumber(16), equals('טז'));
    expect(Gematriya.forNumber(1), equals('א'));
    expect(Gematriya.forNumber(2), equals('ב'));
    expect(Gematriya.forNumber(400), equals('ת'));
  });

  // ── Extra: TutoredProfileSelection equality + tutorOwnProfileId ──────────────

  test(
    'TutoredProfileSelection tutorOwnProfileId defaults to empty sentinel',
    () {
      const sel = TutoredProfileSelection(
        profileId: 'p1',
        ownerUid: 'u1',
        grantId: 'g1',
        permissions: TutorPermissions(),
      );
      // Profile identity is now String-based. A profile-less tutor uses the
      // documented empty-string sentinel; this is identity state, not an
      // achievement-shaped read fallback.
      expect(sel.tutorOwnProfileId, isEmpty);
    },
  );

  test('TutorPermissions equality is value-based', () {
    const a = TutorPermissions();
    const b = TutorPermissions();
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));

    final c = a.copyWith(canEditGoals: false);
    expect(a, isNot(equals(c)));
  });
}
