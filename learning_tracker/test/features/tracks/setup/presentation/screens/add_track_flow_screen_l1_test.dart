/// Firestore-compatible L1 coverage for AddTrackFlow's UI state machine.
@Tags(['needs_flutter', 'l1', 'add_track_flow'])
library;

// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/scope_tiles.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Creation extends Mock implements TrackCreationService {}

const _kTanachScopeContent = <ContentItem>[
  ContentItem(
    curriculumId: 'tanach',
    level1: 'Torah',
    level2: 'Bereshit',
    level3: 'Bereshit 1',
    level4: 'Bereshit 1:1',
    displayNameHe: 'בראשית',
    displayNameEn: 'Bereshit',
    sefariaRef: 'Bereshit',
    sortOrder: 0,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'tanach',
    level1: 'Torah',
    level2: 'Shemot',
    level3: 'Shemot 1',
    level4: 'Shemot 1:1',
    displayNameHe: 'שמות',
    displayNameEn: 'Shemot',
    sefariaRef: 'Shemot',
    sortOrder: 1,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'tanach',
    level1: 'Neviim',
    level2: 'Yehoshua',
    level3: 'Yehoshua 1',
    level4: 'Yehoshua 1:1',
    displayNameHe: 'יהושע',
    displayNameEn: 'Yehoshua',
    sefariaRef: 'Yehoshua 1:1',
    sortOrder: 2,
    isLeaf: true,
  ),
];

class _HebrewOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _app({
  required _Creation creation,
  Locale locale = const Locale('en'),
  VoidCallback? onCancel,
  ValueChanged<AddTrackResult>? onComplete,
  bool withContent = false,
  List<CurriculumId> activeCurricula = const [],
}) {
  return ProviderScope(
    overrides: [
      trackCreationServiceProvider.overrideWithValue(creation),
      if (withContent)
        curriculumContentProvider(CurriculumId.tanach).overrideWithValue(
          const AsyncData<List<ContentItem>>(_kTanachScopeContent),
        ),
      dashboardActiveCurriculaProvider.overrideWith(
        (ref) async => activeCurricula,
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewOff()),
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
      home: Scaffold(
        body: AddTrackFlow(
          isOnboarding: false,
          onComplete: onComplete,
          onCancel: onCancel,
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _chooseSelfPaced(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -300));
  await _settle(tester);
  await tester.tap(find.byIcon(Icons.directions_walk_rounded));
  await _settle(tester);
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(
      const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'fallback',
        studyDays: {1: 'study'},
      ),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first screen shows the curriculum picker', (tester) async {
    await tester.pumpWidget(_app(creation: _Creation()));
    await _settle(tester);
    expect(find.text('Select a Curriculum'), findsOneWidget);
    expect(find.text('Mishnayos'), findsOneWidget);
    expect(find.text('Tanach'), findsOneWidget);
    expect(find.text('Chumash'), findsNothing);
  });

  testWidgets('curriculum picker has no track-type labels', (tester) async {
    await tester.pumpWidget(_app(creation: _Creation()));
    await _settle(tester);
    expect(find.text('Personal'), findsNothing);
    expect(find.text('Standard'), findsNothing);
    expect(find.text('Custom'), findsNothing);
    expect(find.text('אישי'), findsNothing);
  });

  testWidgets('selecting Tanach advances to the program step', (tester) async {
    await tester.pumpWidget(_app(creation: _Creation()));
    await _settle(tester);
    await tester.tap(find.text('Tanach'));
    await _settle(tester);
    expect(find.textContaining('STEP 2'), findsOneWidget);
  });

  testWidgets('back from Tanach program selection returns to picker', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      _app(creation: _Creation(), onCancel: () => cancelled = true),
    );
    await _settle(tester);
    await tester.tap(find.text('Tanach'));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Select a Curriculum'), findsOneWidget);
    expect(cancelled, isFalse);
  });

  testWidgets('Hebrew locale mounts without a localization exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(creation: _Creation(), locale: const Locale('he')),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  group('portable wizard state coverage', () {
    testWidgets(
      'restores the saved scope step and clears stale program state',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.scope.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
          'add_track_program': 42,
          'add_track_program_name': 'Mishna Yomit',
        });
        await tester.pumpWidget(_app(creation: _Creation()));
        await _settle(tester);
        expect(find.textContaining('STEP 2 OF'), findsOneWidget);
        expect(find.text('Mishna Yomit'), findsNothing);
      },
    );

    testWidgets('self-paced Tanach opens its scope step', (tester) async {
      await tester.pumpWidget(_app(creation: _Creation(), withContent: true));
      await _settle(tester);
      await tester.tap(find.text('Tanach'));
      await _settle(tester);
      await _chooseSelfPaced(tester);
      final step = find.textContaining('STEP').first;
      expect(step, findsOneWidget);
      expect(step.evaluate().single.widget, isA<Text>());
      expect(find.textContaining('STEP 3 OF 7'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Torah'),
          matching: find.byType(ScopeLevelTile),
        ),
        findsOneWidget,
      );
    });

    testWidgets('progress increases when advancing from curriculum step', (
      tester,
    ) async {
      await tester.pumpWidget(_app(creation: _Creation()));
      await _settle(tester);
      final before = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      await tester.tap(find.text('Tanach'));
      await _settle(tester);
      final after = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(after, greaterThan(before));
    });

    testWidgets('back from scope returns to program step without cancelling', (
      tester,
    ) async {
      var cancelled = false;
      await tester.pumpWidget(
        _app(
          creation: _Creation(),
          withContent: true,
          onCancel: () => cancelled = true,
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Tanach'));
      await _settle(tester);
      await _chooseSelfPaced(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.textContaining('STEP 2 OF'), findsOneWidget);
      expect(cancelled, isFalse);
    });

    testWidgets('back with saved curriculum shows exit confirmation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.curriculum.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });
      await tester.pumpWidget(_app(creation: _Creation()));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Exit Track Setup?'), findsOneWidget);
    });

    testWidgets('cancel in exit confirmation keeps setup open', (tester) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.curriculum.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });
      var cancelled = false;
      await tester.pumpWidget(
        _app(creation: _Creation(), onCancel: () => cancelled = true),
      );
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Exit Track Setup?'), findsNothing);
      expect(cancelled, isFalse);
    });

    testWidgets('exit in exit confirmation invokes cancellation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.curriculum.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });
      var cancelled = false;
      await tester.pumpWidget(
        _app(creation: _Creation(), onCancel: () => cancelled = true),
      );
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('Exit'));
      await _settle(tester);
      expect(cancelled, isTrue);
    });

    testWidgets('back without saved curriculum calls cancellation directly', (
      tester,
    ) async {
      var cancelled = false;
      await tester.pumpWidget(
        _app(creation: _Creation(), onCancel: () => cancelled = true),
      );
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Exit Track Setup?'), findsNothing);
      expect(cancelled, isTrue);
    });

    testWidgets('failed creation exposes retry and succeeds on retry', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.bulkMark.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });
      final creation = _Creation();
      var calls = 0;
      var completed = false;
      when(() => creation.createTrack(result: any(named: 'result'))).thenAnswer(
        (_) async {
          calls++;
          if (calls == 1) throw Exception('offline');
        },
      );
      await tester.pumpWidget(
        _app(creation: creation, onComplete: (_) => completed = true),
      );
      await _settle(tester);
      await tester.tap(find.text('Skip for now'));
      await _settle(tester);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(calls, 2);
      expect(completed, isTrue);
    });

    testWidgets('existing curriculum opens replace dialog before creation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.bulkMark.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });
      final creation = _Creation();
      when(
        () => creation.createTrack(result: any(named: 'result')),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(
        _app(creation: creation, activeCurricula: [CurriculumId.chumash]),
      );
      await _settle(tester);
      await tester.tap(find.text('Skip for now'));
      await _settle(tester);
      expect(find.textContaining('Replace your'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      verifyNever(() => creation.createTrack(result: any(named: 'result')));
    });

    testWidgets('forwards persisted study days and curriculum to creation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.bulkMark.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
        'add_track_study_days':
            '{"1":"study","2":"study","3":"review",'
            '"4":"review","5":"review","6":"review","7":"review"}',
      });
      final creation = _Creation();
      AddTrackResult? captured;
      when(() => creation.createTrack(result: any(named: 'result'))).thenAnswer(
        (invocation) async {
          captured = invocation.namedArguments[#result] as AddTrackResult;
        },
      );
      await tester.pumpWidget(_app(creation: creation));
      await _settle(tester);
      await tester.tap(find.text('Skip for now'));
      await _settle(tester);
      expect(captured?.curriculumId, CurriculumId.chumash);
      expect(captured?.studyDays[1], 'study');
      expect(captured?.studyDays[3], 'review');
      expect(
        (await SharedPreferences.getInstance()).getInt('add_track_step'),
        isNull,
      );
    });
  });

  testWidgets(
    'program completion write-through remains an individual skip',
    (tester) async {},
    // The program branch still depends on the local calendar/content database
    // for starting-position resolution; no Firestore-backed calendar seam is
    // available within the requested test-only scope.
    skip: true,
  );
}
