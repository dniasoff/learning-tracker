/// Story 2.4 (DNI-495) AC-1, AC-2, AC-3, AC-7 (hub side) and AC-10: the
/// Sub-tracks group in Settings → Manage tracks (`TrackManagementBody`,
/// `/settings/tracks`) and parent mode (`ParentTrackManagementScreen`,
/// `/parent-mode/tracks`).
@Tags(['sub_tracks'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/sub_tracks/sub_track_router.dart';

class _Router extends Mock implements StackRouter {}

/// Fails the first complete read, then delegates (a retryable load error).
final class _FlakyRepository implements SubTrackRepository {
  _FlakyRepository(this.inner);

  final SubTrackRepository inner;
  var _reads = 0;

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) => _reads++ == 0
      ? Stream.error(StateError('read failed'))
      : inner.watchAll(scope);

  @override
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change) =>
      inner.applyGovernedChange(scope, change);
}

const _a = '01JHARN0000000000000000001';
const _b = '01JHARN0000000000000000002';
const _ended = '01JHARN0000000000000000003';

Future<_Router> _pumpHub(
  WidgetTester tester,
  SubTrackHarness h, {
  bool parentSession = true,
  bool subTrackRepository = true,
  bool parentMode = false,
  List<Override> extra = const [],
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
  Size size = const Size(430, 1600),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final router = _Router();
  when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...h.overrides(
          parentSession: parentSession,
          subTrackRepository: subTrackRepository,
        ),
        ...subTrackHubCardOverrides(),
        ...extra,
      ],
      retry: (_, _) => null,
      locale: locale,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: parentMode
            ? const ParentTrackManagementScreen()
            : const TrackManagementBody(showBackButton: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late SubTrackHarness h;

  setUpAll(() {
    registerFallbackValue(const SettingsRoute());
  });

  tearDown(() async => h.dispose());

  group('AC-1 Sub-tracks group', () {
    testWidgets('lists non-ended sub-tracks under the main-track card', (
      tester,
    ) async {
      h = SubTrackHarness(
        seed: [
          storedSchoolYear(_a, name: 'School 2026–27'),
          storedOngoing(_b, name: 'Rebbe'),
          storedSchoolYear(
            _ended,
            name: 'Old school',
            academicYear: 2025,
            ended: true,
          ),
        ],
      );
      await _pumpHub(tester, h);

      expect(find.text('Sub-tracks · 2 active'), findsOneWidget);
      expect(
        find.text(
          'Learning that happens outside home — school, a rebbe, a chavrusa.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SubTrackHubRow), findsNWidgets(2));
      expect(find.text('School 2026–27'), findsOneWidget);
      expect(find.text('School year · Sep–Jul · 10/week'), findsOneWidget);
      expect(find.text('Ongoing · 5/week'), findsOneWidget);
      expect(find.text('Old school'), findsNothing);
      expect(find.text('Add sub-track'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(LearningTrackCard)).dy,
        lessThan(tester.getTopLeft(find.text('Sub-tracks · 2 active')).dy),
      );
    });

    testWidgets('with no sub-tracks: only the header and Add sub-track', (
      tester,
    ) async {
      h = SubTrackHarness();
      await _pumpHub(tester, h);
      expect(find.text('Sub-tracks · 0 active'), findsOneWidget);
      expect(find.text('Add sub-track'), findsOneWidget);
      expect(
        find.textContaining('Learning that happens outside home'),
        findsNothing,
      );
      expect(find.byType(SubTrackHubRow), findsNothing);
    });

    testWidgets('a load error shows the retryable error view in the group', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      final flaky = _FlakyRepository(h.repo);
      await _pumpHub(
        tester,
        h,
        subTrackRepository: false,
        extra: [subTrackRepositoryProvider.overrideWith((ref) async => flaky)],
      );
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byType(LearningTrackCard), findsOneWidget);
      expect(find.text('Add sub-track'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('Sub-tracks · 1 active'), findsOneWidget);
    });

    // Story 2.6 (DNI-497, AC-1, UX-DR-53): a row opens the sub-track
    // detail; metadata Edit moved into the detail's ⋮.
    for (final (label, stored) in [
      ('school-year', storedSchoolYear(_a)),
      ('ongoing', storedOngoing(_a, name: 'Rebbe')),
    ]) {
      testWidgets('on a phone, tapping a $label row pushes its sub-track '
          'detail and selects it', (tester) async {
        h = SubTrackHarness(seed: [stored]);
        final router = await _pumpHub(tester, h);
        final row = find.byKey(const ValueKey('subTrackHubRow:$_a'));
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        await tester.tap(row);
        await tester.pump();
        final pushed =
            verify(() => router.push<Object?>(captureAny())).captured.single
                as SubTrackDetailRoute;
        expect(pushed.args!.subTrackId, _a);
        await tester.pump();
        expect(tester.widget<ListTile>(row).selected, isTrue);
      });
    }

    testWidgets('from 840dp a row tap selects it and shows its detail beside '
        'the hub without pushing; the next tap moves the selection', (
      tester,
    ) async {
      h = SubTrackHarness(
        seed: [
          storedSchoolYear(_a),
          storedOngoing(_b, name: 'Rebbe'),
        ],
      );
      final router = await _pumpHub(tester, h, size: const Size(1100, 1600));
      final pane = find.byKey(const ValueKey('subTrackSplitDetail'));
      expect(pane, findsNothing);
      ListTile tile(String id) =>
          tester.widget<ListTile>(find.byKey(ValueKey('subTrackHubRow:$id')));

      await tester.tap(find.byKey(const ValueKey('subTrackHubRow:$_a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pane, findsOneWidget);
      expect(tile(_a).selected, isTrue);

      await tester.tap(find.byKey(const ValueKey('subTrackHubRow:$_b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pane, findsOneWidget);
      expect(tile(_b).selected, isTrue);
      expect(tile(_a).selected, isFalse);
      verifyNever(() => router.push<Object?>(any()));
    });

    testWidgets('Add sub-track offers School year and Ongoing', (tester) async {
      h = SubTrackHarness();
      final router = await _pumpHub(tester, h);
      await tester.tap(find.text('Add sub-track'));
      await tester.pumpAndSettle();
      expect(find.text('School year'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
      await tester.tap(find.text('School year'));
      await tester.pumpAndSettle();
      final pushed =
          verify(() => router.push<Object?>(captureAny())).captured.single
              as SchoolYearSubTrackFormRoute;
      expect(pushed.args!.curriculumId, 'mishnayos');
      expect(pushed.args!.subTrackId, isNull);
    });

    testWidgets('parent mode shows the same group', (tester) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      await _pumpHub(tester, h, parentMode: true);
      expect(find.text('Sub-tracks · 1 active'), findsOneWidget);
      expect(find.text('Add sub-track'), findsOneWidget);
    });
  });

  group('AC-2 calendar program', () {
    testWidgets('hides the group and Add sub-track', (tester) async {
      h = SubTrackHarness(calendarProgramId: 'daf_yomi');
      await _pumpHub(tester, h);
      expect(find.byType(LearningTrackCard), findsOneWidget);
      expect(find.textContaining('Sub-tracks'), findsNothing);
      expect(find.text('Add sub-track'), findsNothing);
    });
  });

  group('AC-3 child session', () {
    testWidgets('a child without the parent PIN sees no sub-track entry', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      await _pumpHub(tester, h, parentSession: false);
      expect(find.byType(LearningTrackCard), findsOneWidget);
      expect(find.textContaining('Sub-tracks'), findsNothing);
      expect(find.byType(SubTrackHubRow), findsNothing);
      expect(find.text('Add sub-track'), findsNothing);
    });
  });

  group('AC-7 hub side', () {
    SubTrackDraft draft() => const SubTrackDraft(
      curriculumId: subTrackTestCurriculum,
      name: 'Cheder',
      type: SubTrackType.schoolYear,
      academicYear: 2026,
      windowStart: '2026-09-01',
      windowEnd: '2027-07-31',
      ratePerWeek: 10,
      weeksPerYear: 39,
      learnsOnShabbos: false,
      ground: [],
    );

    testWidgets('an offline create shows its row at once and the target '
        'recomputes', (tester) async {
      h = SubTrackHarness(deadline: '2028-06-01')..repo.offline = true;
      await _pumpHub(tester, h);
      expect(find.text('Sub-tracks · 0 active'), findsOneWidget);

      late CaptureResult result;
      await tester.runAsync(() async {
        result = await h.commands.createSubTrack(draft());
      });
      await tester.pumpAndSettle();
      expect(
        result,
        isA<CaptureSuccess>().having((s) => s.queued, 'queued', true),
      );
      expect(find.text('Sub-tracks · 1 active'), findsOneWidget);
      expect(find.text('Cheder'), findsOneWidget);
      // Stand-in engine: 30 − 10/week.
      expect(find.text('Daily target: 20 mishnayos'), findsOneWidget);
    });

    testWidgets('a batch rejected at sync removes the row and says so', (
      tester,
    ) async {
      h = SubTrackHarness()
        ..repo.offline = true
        ..repo.failNextWith(const PermanentWriteRejection('permission-denied'));
      await _pumpHub(tester, h);
      await tester.runAsync(() => h.commands.createSubTrack(draft()));
      await tester.pumpAndSettle();
      expect(find.text('Cheder'), findsOneWidget);

      await tester.runAsync(() async {
        h.repo.settleHeld();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pumpAndSettle();
      expect(find.text('Cheder'), findsNothing);
      expect(find.text('Sub-tracks · 0 active'), findsOneWidget);
      expect(find.text("Your change couldn't be saved."), findsOneWidget);
    });
  });

  group('AC-10 styling and layouts', () {
    testWidgets('rows are flat cards with a 1px outline', (tester) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      await _pumpHub(tester, h);
      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(SubTrackHubRow),
          matching: find.byType(Card),
        ),
      );
      expect(card.elevation, 0);
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 1);
      expect(shape.borderRadius, BorderRadius.circular(18));
      expect(
        tester.getSize(find.byType(SubTrackHubRow)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('dark and Hebrew render cleanly, right-to-left', (
      tester,
    ) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      await _pumpHub(
        tester,
        h,
        theme: AppTheme.themeFor(brightness: Brightness.dark),
        locale: const Locale('he'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('תתי-מסלולים · 1 פעילים'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(SubTrackHubSection))),
        TextDirection.rtl,
      );
    });

    testWidgets('the group at maximum text scale: no clipping, 48dp '
        'targets', (tester) async {
      h = SubTrackHarness(seed: [storedSchoolYear(_a)]);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 2000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pumpApp(
          overrides: h.overrides(),
          retry: (_, _) => null,
          locale: const Locale('he'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: const [
                SubTrackHubSection(curriculumId: subTrackTestCurriculum),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.widgetWithText(OutlinedButton, 'הוספת תת-מסלול'))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byType(SubTrackHubRow)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
