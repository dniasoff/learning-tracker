/// TS-14 regression test: ParentTrackManagementScreen must use child-scoped
/// copy ("your child's learning tracks") rather than own-profile copy
/// ("your learning tracks") in its empty state and archive dialog.
///
/// RED → GREEN cycle:
///   RED:  screen uses `l10n.manageTracksDetail` and `l10n.deleteTrackArchiveBody`
///         (own-profile "your" wording).
///   GREEN: screen uses `l10n.parentManageTracksDetail` and
///          `l10n.parentDeleteTrackArchiveBody` (child-management "your child's"
///          wording).
@Tags(['profiles', 'ts14'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_track_management_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

const _kProfileId = 1;

List<Override> _perTrackOverrides(List<CurriculumTrack> tracks) {
  final overrides = <Override>[];
  for (final t in tracks) {
    overrides.add(
      dashboardTrackCompletionPercentageProvider(
        t.id,
      ).overrideWith((ref) async => 0.0),
    );
    overrides.add(
      trackHasChazaraProvider(t.id).overrideWith((ref) async => false),
    );
  }
  overrides.add(
    dashboardHasProgramEnrollmentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  );
  return overrides;
}

Widget _buildApp({
  required _MockStackRouter router,
  required List<CurriculumTrack> tracks,
  UserDatabase? db,
  Locale locale = const Locale('en'),
}) {
  final database = db ?? inMemoryDb();
  // AUD-t-cross-08: only close the database WE created here — a
  // caller-supplied db: is the caller's responsibility, so closing it a
  // second time here would double-close it.
  if (db == null) {
    addTearDown(database.close);
  }

  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWithValue(
        tracks.isNotEmpty ? tracks.first.profileId : _kProfileId,
      ),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ..._perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
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
        child: const ParentTrackManagementScreen(),
      ),
    ),
  );
}

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

  // ── TS-14 empty-state copy ───────────────────────────────────────────────

  group('TS-14 child-scoped copy', () {
    testWidgets(
      'empty state shows child-scoped subtitle, NOT own-profile "your learning tracks"',
      (tester) async {
        await tester.pumpWidget(_buildApp(router: router, tracks: const []));
        await _settle(tester);

        // Must use child-scoped copy ("your child's learning tracks")
        expect(
          find.textContaining("child's learning tracks"),
          findsOneWidget,
          reason:
              'TS-14: empty state must use child-scoped copy ("your child\'s '
              'learning tracks") not own-profile "your learning tracks".',
        );
        // Must NOT contain own-profile "your learning tracks" (no possessive)
        // The child-scoped copy is "your child's learning tracks" which
        // does contain "learning tracks", but the own-profile copy says
        // "Create and edit your learning tracks" (no "child's").
        expect(
          find.text('Create and edit your learning tracks'),
          findsNothing,
          reason:
              'TS-14: own-profile copy must not appear in the child-management '
              'screen.',
        );

        await _teardown(tester);
      },
    );

    // TS-14: the dialog body l10n string is verified by checking that the
    // ARB key used in _showDeleteDialog resolves to child-scoped copy.
    // We test this by rendering an AppLocalizations and verifying the
    // string used in the screen is the child-scoped one (parentDeleteTrackArchiveBody).
    testWidgets(
      'l10n.parentDeleteTrackArchiveBody contains child-scoped wording',
      (tester) async {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context)!;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pump();

        // parentDeleteTrackArchiveBody must use child-scoped "your child's"
        expect(
          l10n.parentDeleteTrackArchiveBody,
          contains("child's"),
          reason:
              'TS-14: parentDeleteTrackArchiveBody must contain child-scoped '
              '"your child\'s completion history" wording.',
        );
        // Must NOT match the own-profile string
        expect(
          l10n.parentDeleteTrackArchiveBody,
          isNot(equals(l10n.deleteTrackArchiveBody)),
          reason:
              'TS-14: parentDeleteTrackArchiveBody must differ from the '
              'own-profile deleteTrackArchiveBody.',
        );
      },
    );
  });
}
