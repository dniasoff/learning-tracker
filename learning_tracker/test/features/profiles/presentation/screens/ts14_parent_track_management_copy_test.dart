/// TS-14 regression test for child-scoped parent track-management copy.
@Tags(['profiles', 'ts14'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FixedActiveProfileDocId extends ActiveProfileDocId {
  _FixedActiveProfileDocId(this._id);
  final String _id;

  @override
  String? build() => _id;
}

const _uid = 'uid-ts14';
const _profileId = '01HTS14PROFILE0000000000000';

CurriculumTrackEntity _track(CurriculumId curriculumId) =>
    CurriculumTrackEntity(
      curriculumId: curriculumId,
      state: 'active',
      stateChangedAt: DateTime.utc(2026, 1, 1),
      activatedAt: DateTime.utc(2026, 1, 1),
    );

List<Override> _perTrackOverrides(List<CurriculumTrackEntity> tracks) => [
  for (final track in tracks) ...[
    dashboardTrackCompletionPercentageProvider(
      track.curriculumId,
    ).overrideWith((ref) async => 0.0),
    trackHasChazaraProvider(
      track.curriculumId,
    ).overrideWith((ref) async => false),
  ],
  dashboardHasProgramEnrollmentProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) async => false),
];

Widget _buildApp({
  required _MockStackRouter router,
  required FakeFirebaseFirestore firestore,
  required List<CurriculumTrackEntity> tracks,
}) {
  return pumpApp(
    overrides: [
      activeProfileIdProvider.overrideWithValue(_profileId),
      activeProfileDocIdProvider.overrideWith(
        () => _FixedActiveProfileDocId(_profileId),
      ),
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => AccountFirebaseHandles(
          app: _MockFirebaseApp(),
          firestore: firestore,
          auth: _MockFirebaseAuth(),
          uid: _uid,
        ),
      ),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const ParentTrackManagementScreen(),
    ),
  );
}

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<dynamic>(any<dynamic>()),
    ).thenAnswer((_) async => true);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(
      () => router.navigate(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
  });

  testWidgets('empty state shows child-scoped subtitle, not own-profile copy', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: const []),
    );
    await _settle(tester);

    expect(find.textContaining("child's learning tracks"), findsOneWidget);
    expect(find.text('Create and edit your learning tracks'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('real archive dialog renders child-scoped copy', (tester) async {
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
    final track = _track(CurriculumId.mishnayos);

    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, tracks: [track]),
    );
    await _settle(tester);
    await tester.longPress(find.byType(InkWell).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ParentTrackManagementScreen)),
    )!;
    expect(find.text(l10n.parentDeleteTrackArchiveBody), findsOneWidget);
    expect(find.text(l10n.deleteTrackArchiveBody), findsNothing);
    await _teardown(tester);
  });
}
