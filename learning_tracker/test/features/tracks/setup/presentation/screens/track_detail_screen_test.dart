/// Firestore-native L1 coverage for TrackDetailScreen.
@Tags(['tracks', 'track_detail', 'l1'])
library;
// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/firestore_fake.dart';
import '../../../../../helpers/firestore_fixtures.dart';

const _uid = 'track-detail-screen-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY6';

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Widget _app({
  required FakeFirebaseFirestore firestore,
  required CurriculumTrackEntity track,
  bool program = false,
  bool chazara = false,
  double dashboardCompletion = 0,
  double cycle = 0,
  double lifetime = 0,
}) => ProviderScope(
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
    ).overrideWith((ref) async => dashboardCompletion),
    dashboardHasProgramEnrollmentProvider(
      track.curriculumId,
    ).overrideWith((ref) async => program),
    trackHasChazaraProvider(
      track.curriculumId,
    ).overrideWith((ref) async => chazara),
    scopedItemCountProvider(
      track.curriculumId,
    ).overrideWith((ref) async => 100),
    trackDualProgressMetricsProvider.overrideWith(
      (ref) async => [
        TrackDualProgressMetric(
          trackLabel: 'Mishnayos',
          curriculumId: track.curriculumId,
          currentCyclePercentage: cycle,
          lifetimePercentage: lifetime,
          isProgramTrack: program,
        ),
      ],
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: TrackDetailScreen(track: track),
  ),
);

Future<FakeFirebaseFirestore> _seed({String? description}) async {
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  if (description != null) {
    await seedGoal(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      description: description,
      goalType: 'pace',
      paceValue: 4,
      pacePeriod: 'per_week',
    );
  }
  return firestore;
}

void main() {
  testWidgets(
    'dual progress labels render from the real screen provider path',
    (tester) async {
      final firestore = await _seed();
      await tester.pumpWidget(
        _app(firestore: firestore, track: _track(), cycle: .4, lifetime: .6),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Track progress: 40%'), findsOneWidget);
      expect(find.text('Lifetime: 60%'), findsOneWidget);
    },
  );

  testWidgets('goal row uses the Firestore-seeded goal', (tester) async {
    final firestore = await _seed(description: 'My Shas Journey');
    await tester.pumpWidget(_app(firestore: firestore, track: _track()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('My Shas Journey'), findsWidgets);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('divergent dashboard and cycle metrics keep distinct labels', (
    tester,
  ) async {
    final firestore = await _seed();
    await tester.pumpWidget(
      _app(
        firestore: firestore,
        track: _track(),
        dashboardCompletion: .62,
        cycle: .20,
        lifetime: .74,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Track progress: 20%'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('Track progress'), findsNothing);
  });

  testWidgets('zero-valued dual metrics still render both labels', (
    tester,
  ) async {
    final firestore = await _seed();
    await tester.pumpWidget(_app(firestore: firestore, track: _track()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Track progress: 0%'), findsOneWidget);
    expect(find.text('Lifetime: 0%'), findsOneWidget);
  });

  testWidgets('a track without a goal exposes Set Goal', (tester) async {
    final firestore = await _seed();
    await tester.pumpWidget(_app(firestore: firestore, track: _track()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('trackDetail.goalTile')), findsOneWidget);
    expect(find.text('Set Goal'), findsOneWidget);
  });

  testWidgets('non-program action tiles preserve their product intent', (
    tester,
  ) async {
    final firestore = await _seed();
    await tester.pumpWidget(_app(firestore: firestore, track: _track()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Edit Track'), findsOneWidget);
    expect(find.text('Delete Track'), findsOneWidget);
    expect(find.text('Mark as previously learned'), findsOneWidget);
    expect(find.text('Reorder Content'), findsOneWidget);
  });

  testWidgets('program tracks hide self-paced-only actions', (tester) async {
    final firestore = await _seed();
    await tester.pumpWidget(
      _app(firestore: firestore, track: _track(), program: true),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mark as previously learned'), findsNothing);
    expect(find.text('Reorder Content'), findsNothing);
  });

  testWidgets('chazara header is gated by the curriculum stage result', (
    tester,
  ) async {
    final firestore = await _seed();
    await tester.pumpWidget(
      _app(firestore: firestore, track: _track(), chazara: false),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Chazara'), findsNothing);
  });
}
