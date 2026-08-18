/// Firestore-native L1 coverage for the track-management hub.
@Tags(['tracks', 'track_management_hub'])
library;

// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:auto_route/auto_route.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/firestore_fake.dart';
import '../../../helpers/firestore_fixtures.dart';

class _Router extends Mock implements StackRouter {}

class FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

const _uid = 'track-hub-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

CurriculumTrackEntity _track(CurriculumId curriculum) => CurriculumTrackEntity(
  curriculumId: curriculum,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Widget _app({
  required _Router router,
  required FakeFirebaseFirestore firestore,
  required List<CurriculumTrackEntity> tracks,
  Locale locale = const Locale('en'),
  Stream<List<CurriculumTrackEntity>>? activeStream,
}) => ProviderScope(
  retry: (_, __) => null,
  overrides: [
    activeProfileIdProvider.overrideWithValue(_profileId),
    if (activeStream != null)
      activeTracksProvider.overrideWith((ref) => activeStream)
    else
      activeTracksProvider.overrideWith(
        (ref) => FirestoreCurriculumTrackRepository(
          firestore: firestore,
          uid: _uid,
          profileId: _profileId,
        ).watchActiveTracks(),
      ),
    firestoreCurriculumTrackRepositoryProvider.overrideWith(
      (ref) async => FirestoreCurriculumTrackRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ),
    ),
    curriculumTrackRepositoryAdapterProvider.overrideWith(
      (ref) => FirestoreCurriculumTrackRepositoryAdapter(
        ref: ref,
        functions: _MockFirebaseFunctions(),
      ),
    ),
    firestoreStudyDayConfigRepositoryProvider.overrideWith(
      (ref) async => FirestoreStudyDayConfigRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      ),
    ),
    dashboardActiveCurriculaProvider.overrideWith(
      (ref) => Future.value(tracks.map((track) => track.curriculumId).toList()),
    ),
    for (final track in tracks) ...[
      dashboardTrackCompletionPercentageProvider(
        track.curriculumId,
      ).overrideWith((ref) async => 0),
      trackHasChazaraProvider(
        track.curriculumId,
      ).overrideWith((ref) async => false),
    ],
    useHebrewTermsProvider.overrideWith(() => _HebrewOff()),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const TrackManagementHubScreen(),
    ),
  ),
);

void main() {
  setUpAll(() => registerFallbackValue(FakePageRouteInfo()));

  testWidgets('empty state shows the add-track action', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final router = _Router();
    await tester.pumpWidget(
      _app(router: router, firestore: firestore, tracks: const []),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No tracks yet'), findsOneWidget);
    expect(find.text('Add Your First Track'), findsOneWidget);
  });

  testWidgets('empty state does not show the populated-state FAB', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _app(router: _Router(), firestore: firestore, tracks: const []),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ADD TRACK'), findsNothing);
  });

  testWidgets('Firestore-seeded active track renders in the populated state', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    final router = _Router();
    await tester.pumpWidget(
      _app(
        router: router,
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Active Tracks'), findsOneWidget);
    expect(find.textContaining('1 RUNNING'), findsOneWidget);
    expect(find.text('ADD TRACK'), findsOneWidget);
  });

  testWidgets('tapping a track routes through the real hub interaction', (
    tester,
  ) async {
    final router = _Router();
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(
      _app(
        router: router,
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(InkWell).first);
    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);
  });

  testWidgets('populated hub shows its title and add-track FAB', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await tester.pumpWidget(
      _app(
        router: _Router(),
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Manage Tracks'), findsOneWidget);
    expect(find.text('ADD TRACK'), findsOneWidget);
  });

  testWidgets('active-track errors use AppErrorView without leaking details', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _app(
        router: _Router(),
        firestore: firestore,
        tracks: const [],
        activeStream: Stream<List<CurriculumTrackEntity>>.error(
          Exception('backend detail'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('backend detail'), findsNothing);
  });

  testWidgets('RTL populated hub mounts without overflow', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await tester.pumpWidget(
      _app(
        router: _Router(),
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
        locale: const Locale('he'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press opens the Firestore-backed delete dialog', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    await tester.pumpWidget(
      _app(
        router: _Router(),
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final mishnayosCard = find.ancestor(
      of: find.text('Mishnayos'),
      matching: find.byType(InkWell),
    );
    expect(mishnayosCard, findsOneWidget);
    await tester.longPress(mishnayosCard);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Delete Track'), findsOneWidget);
    expect(find.text('Archive (keep history)'), findsOneWidget);
    expect(find.text('Delete and wipe history'), findsOneWidget);
  });

  testWidgets('archive action retires the selected Firestore track', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.bavli,
    );
    await tester.pumpWidget(
      _app(
        router: _Router(),
        firestore: firestore,
        tracks: [_track(CurriculumId.mishnayos)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final mishnayosCard = find.ancestor(
      of: find.text('Mishnayos'),
      matching: find.byType(InkWell),
    );
    expect(mishnayosCard, findsOneWidget);
    await tester.longPress(mishnayosCard);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Archive (keep history)'));
    await tester.pump(const Duration(milliseconds: 500));

    final stored = await FirestoreCurriculumTrackRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    ).getTrack(CurriculumId.mishnayos);
    expect(stored?.isActive, isFalse);
    expect(stored?.state, 'retired');
  });
}
