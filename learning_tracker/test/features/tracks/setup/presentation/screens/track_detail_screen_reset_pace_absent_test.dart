/// DNI-484 (story 1.22, AC-1 / AC-2) — the retired "Reset pace" control is
/// gone from every track surface that offers pace actions, and the retained
/// `activated_at` is display-only.
///
/// Surfaces: Track Detail (with its Track Info card, which shows the pace
/// goal and the actual-pace row) and the goal form (the pace editor), each
/// in both supported locales. The EN / HE catalogs carry no Reset pace copy,
/// so no screen can render it.
@Tags(['tracks', 'track_detail', 'l1'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/firestore_fake.dart';
import '../../../../../helpers/firestore_fixtures.dart';

const _uid = 'reset-pace-absent-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

/// "Reset pace" in either catalog's wording (EN, and HE "איפוס קצב").
final _resetPaceCopy = RegExp(
  r'reset\s*(the\s*)?pace|pace\s*reset|איפוס\s*(ה)?קצב',
  caseSensitive: false,
);

const _locales = [Locale('en'), Locale('he')];

CurriculumTrackEntity _track({DateTime? activatedAt}) => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  activatedAt: activatedAt,
);

Widget _localized({
  required Locale locale,
  required Widget home,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Widget _detail({
  required FakeFirebaseFirestore firestore,
  required CurriculumTrackEntity track,
  required Locale locale,
}) => _localized(
  locale: locale,
  overrides: [
    firestoreGoalRepositoryProvider.overrideWith(
      (ref) async => FirestoreGoalRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ),
    ),
    firestoreStageDefinitionRepositoryProvider.overrideWith(
      (ref) async => FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ),
    ),
    dashboardTrackCompletionPercentageProvider(
      track.curriculumId,
    ).overrideWith((ref) async => 0),
    dashboardHasProgramEnrollmentProvider(
      track.curriculumId,
    ).overrideWith((ref) async => false),
    trackHasChazaraProvider(
      track.curriculumId,
    ).overrideWith((ref) async => false),
    scopedItemCountProvider(
      track.curriculumId,
    ).overrideWith((ref) async => 100),
    trackDualProgressMetricsProvider.overrideWith(
      (ref) async => [
        TrackDualProgressMetric(
          trackLabel: 'Mishnayos',
          curriculumId: track.curriculumId,
          currentCyclePercentage: .2,
          lifetimePercentage: .3,
          isProgramTrack: false,
        ),
      ],
    ),
  ],
  home: TrackDetailScreen(track: track),
);

/// A pace goal on the fixed `goals/{c}_pace`-shaped entity.
Future<FakeFirebaseFirestore> _withPaceGoal() async {
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  await seedGoal(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.mishnayos,
    goalType: 'pace',
    paceValue: 2,
    pacePeriod: 'per_day',
  );
  return firestore;
}

void _expectNoResetPace(WidgetTester tester) {
  expect(find.textContaining(_resetPaceCopy), findsNothing);
  expect(
    find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey &&
          _resetPaceCopy.hasMatch(key.value.toString().replaceAll('_', ' '));
    }),
    findsNothing,
  );
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    // Nothing further down a scroll view either.
    expect(
      find.descendant(
        of: scrollables.first,
        matching: find.textContaining(_resetPaceCopy),
      ),
      findsNothing,
    );
  }
}

void main() {
  group('AC-1: no Reset pace control on any pace surface', () {
    for (final locale in _locales) {
      testWidgets('Track Detail with a pace goal (${locale.languageCode})', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final firestore = await _withPaceGoal();
        await tester.pumpWidget(
          _detail(
            firestore: firestore,
            track: _track(activatedAt: DateTime.utc(2026, 1, 1)),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(TrackDetailScreen), findsOneWidget);
        _expectNoResetPace(tester);
      });

      testWidgets('the goal form editing a pace goal '
          '(${locale.languageCode})', (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _localized(
            locale: locale,
            home: GoalSetupScreen(
              curriculumId: CurriculumId.mishnayos,
              existingGoal: GoalEntity(
                curriculumId: CurriculumId.mishnayos,
                goalType: 'pace',
                paceValue: 2,
                pacePeriod: 'per_day',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(GoalSetupForm), findsOneWidget);
        _expectNoResetPace(tester);
        // R16: no target-percent control either (AD-43).
        expect(find.byType(Slider), findsNothing);
      });
    }
  });

  group('AC-1: no Reset pace copy in either catalog', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_he.arb']) {
      test(arb, () {
        final catalog =
            jsonDecode(File(arb).readAsStringSync()) as Map<String, dynamic>;
        for (final entry in catalog.entries) {
          final key = entry.key.replaceAllMapped(
            RegExp('([a-z])([A-Z])'),
            (m) => '${m[1]} ${m[2]}',
          );
          expect(_resetPaceCopy.hasMatch(key), isFalse, reason: entry.key);
          final value = entry.value;
          if (value is String) {
            expect(_resetPaceCopy.hasMatch(value), isFalse, reason: entry.key);
          }
        }
      });
    }
  });

  group('AC-2: activated_at is display-only', () {
    testWidgets('a track with activated_at shows its Started / Since date', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = await _withPaceGoal();
      await tester.pumpWidget(
        _detail(
          firestore: firestore,
          track: _track(activatedAt: DateTime.utc(2026, 1, 1)),
          locale: const Locale('en'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Since '), findsOneWidget);
      expect(find.text('Started'), findsOneWidget);
    });

    testWidgets('a track without activated_at still renders and omits the '
        'Started / Since / Elapsed rows', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firestore = await _withPaceGoal();
      await tester.pumpWidget(
        _detail(
          firestore: firestore,
          track: _track(),
          locale: const Locale('en'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TrackDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Since '), findsNothing);
      expect(find.text('Started'), findsNothing);
      expect(find.text('Elapsed'), findsNothing);
    });
  });
}
