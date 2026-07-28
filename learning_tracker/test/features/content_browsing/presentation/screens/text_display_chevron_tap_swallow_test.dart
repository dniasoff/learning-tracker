// RED DEMO — reader chevron tap-swallow (deferred item, run11-acceptance
// -sweep, docs/test-artifacts/run11-acceptance-sweep.md).
//
// text_display_screen_test.dart's navigation tests use a MOCKTAIL
// `_MockStackRouter` — `router.replace(...)` is verified as CALLED but never
// actually performs a navigation, so the widget never rebuilds with a new
// `sefariaRef` and the loading-gap this bug lives in is never exercised.
//
// This file boots a REAL (non-mocked) auto_route `RootStackRouter` hosting
// only `TextDisplayRoute`, so `context.router.replace(...)` (the pre-fix
// implementation) performs an ACTUAL page replace: the old
// `TextDisplayScreen` is torn down and a new one mounted for the new
// `sefariaRef` — exactly like the app's real `AppRouter` does for this route
// (minus unrelated auth/profile guards, irrelevant to this bug). Reverting
// text_display_screen.dart's chevron `onPressed` handlers to
// `context.router.replace(TextDisplayRoute(sefariaRef: adj.next!))` (and
// restoring the async `adjacentContentRefsProvider` read) reproduces the RED
// failure below.
//
// `curriculumContentProvider` (the dependency `contentIndexProvider` awaits
// to warm up) is overridden with an artificial delay so the initial-load gap
// is deterministic instead of racing on the host's actual disk-cache speed.
@Tags(['needs_flutter', 'content_browsing', 'text_display'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart'
    show TextDisplayRoute;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

import '../../../../helpers/pump_app.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _kItemCount = 8;

/// Sequential leaf refs within a single (fake) chapter — `ContentIndex`
/// walks same-curriculum leaves sorted by `sortOrder`, so these form a
/// simple 0..7 chain the chevrons can walk end to end.
String _refAt(int i) => 'Mishnah_Berakhot.1.${i + 1}';

/// What the reader body shows for [ref] — driven entirely by the
/// `textContentProvider` override below, so it is unaffected by AppBar
/// title / curriculum-label plumbing. This is the assertion signal: "what
/// is the user actually looking at right now".
String _bodyTextAt(String ref) => 'Text for $ref';

List<ContentItem> _sequentialItems() => List.generate(
  _kItemCount,
  (i) => ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    displayNameHe: 'משנה ${i + 1}',
    displayNameEn: 'Mishnah ${i + 1}',
    sefariaRef: _refAt(i),
    sortOrder: i,
    isLeaf: true,
  ),
);

/// A minimal REAL `RootStackRouter` hosting only [TextDisplayRoute]. Not a
/// mocktail mock — `replace`/`push` run the genuine auto_route stack
/// machinery, so the widget really rebuilds on navigation.
class _ReaderOnlyRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/text/:sefariaRef', page: TextDisplayRoute.page),
  ];
}

Widget _buildRealRouterApp({
  required _ReaderOnlyRouter router,
  required Duration curriculumDelay,
  required String initialRef,
}) {
  // pumpApp's `routerConfig` param (test/helpers/pump_app.dart) drives a real
  // MaterialApp.router through the shared delegate-list definition — TQ-3
  // forbids hand-rolling a second `MaterialApp.router(localizationsDelegates:
  // [...])` block here.
  return pumpApp(
    routerConfig: router.config(
      deepLinkBuilder: (_) => DeepLink.path('/text/$initialRef'),
    ),
    overrides: [
      // The one real dependency `contentIndexProvider` needs to warm up.
      // mishnayos resolves the fake chain after [curriculumDelay] — every
      // OTHER curriculum resolves instantly empty.
      curriculumContentProvider.overrideWith((ref, curriculumId) async {
        if (curriculumId != CurriculumId.mishnayos) {
          return const <ContentItem>[];
        }
        await Future<void>.delayed(curriculumDelay);
        return _sequentialItems();
      }),
      textContentProvider.overrideWith(
        (ref, sefariaRef) async => TextContent.single(
          sefariaRef: sefariaRef,
          hebrewText: 'טקסט',
          englishText: _bodyTextAt(sefariaRef),
        ),
      ),
      // Not under test here — pin to something trivial and instant so the
      // AppBar title never blocks/races the chevron-focused assertions.
      renderedDisplayForRefProvider.overrideWith(
        (ref, sefariaRef) async => sefariaRef,
      ),
      // AppBar title also folds in a curriculum-name prefix once
      // contentIndexProvider resolves and matches our fake items'
      // curriculumId ('mishnayos') — irrelevant to this test (which asserts
      // on the reader BODY, not the title), but `curriculumLabelText`'s
      // dependency chain still needs safe, DB-free values to avoid
      // throwing mid-build.
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      currentTransliterationVariantProvider.overrideWith(
        () => _FakeTransliterationVariant(),
      ),
      // No daily tasks — _CompletionSection short-circuits to SizedBox.shrink
      // so its own provider tree (trackType/isStageCompleted/tutor session)
      // never needs wiring for this test.
      allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    ],
  );
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeTransliterationVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

// ─── Tests ────────────────────────────────────────────────────────────────────
//
// Assertions check the RENDERED reader body text (== "Text for <ref>", via
// the `textContentProvider` override above) rather than the router's path.
// This is deliberate: the fix under test drives the displayed ref from
// in-widget state rather than route replacement, so the router's path is no
// longer a reliable proxy for "what is on screen" once fixed — the
// on-screen text is the one signal that is meaningful both before and after
// the fix.

void main() {
  testWidgets(
    'rapid next-chevron taps (short pumps between) each advance exactly one '
    'item — REAL router, no tap loss',
    (tester) async {
      final router = _ReaderOnlyRouter();
      await tester.pumpWidget(
        _buildRealRouterApp(
          router: router,
          curriculumDelay: const Duration(milliseconds: 40),
          initialRef: _refAt(0),
        ),
      );
      // Settle the initial mount (contentIndex resolves once).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_bodyTextAt(_refAt(0))), findsOneWidget);

      const tapCount = 5;
      for (var i = 0; i < tapCount; i++) {
        await tester.tap(find.byKey(const Key('text_display_next_button')));
        // SHORT pump — a single ~one-frame gap, mirroring a real user's
        // finger lifting and tapping again quickly (rapid, not simultaneous).
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Let any in-flight async work finish.
      await tester.pumpAndSettle();

      expect(
        find.text(_bodyTextAt(_refAt(tapCount))),
        findsOneWidget,
        reason:
            '$tapCount deliberate next-chevron taps must advance exactly '
            '$tapCount items with zero loss; not landing on '
            '${_refAt(tapCount)} means one or more taps were swallowed.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'rapid next-chevron taps followed by pumpAndSettle still advance exactly '
    'N items — REAL router, no tap loss',
    (tester) async {
      final router = _ReaderOnlyRouter();
      await tester.pumpWidget(
        _buildRealRouterApp(
          router: router,
          curriculumDelay: const Duration(milliseconds: 40),
          initialRef: _refAt(0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_bodyTextAt(_refAt(0))), findsOneWidget);

      const tapCount = 5;
      for (var i = 0; i < tapCount; i++) {
        await tester.tap(find.byKey(const Key('text_display_next_button')));
        // Zero-duration pump — as fast as taps can register at all (still
        // needs one frame for `setState` to take effect before the next
        // tap, since Flutter can't dispatch a second gesture mid-build).
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        find.text(_bodyTextAt(_refAt(tapCount))),
        findsOneWidget,
        reason:
            '$tapCount rapid taps (settled via pumpAndSettle) must still '
            'advance exactly $tapCount items with zero loss.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
