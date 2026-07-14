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
///
/// AUD-t-profiles-04: the dialog-body test used to read
/// `AppLocalizations.of(context)!.parentDeleteTrackArchiveBody` from a bare
/// `Builder` instead of opening the real dialog, so it could not catch
/// `_showDeleteDialog` being edited to reference the sibling own-profile key
/// (`deleteTrackArchiveBody`) instead. It now longPresses the real
/// [ParentTrackManagementScreen] and asserts on the rendered dialog's `Text`.
@Tags(['profiles', 'ts14'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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
import '../../../../helpers/pump_app.dart';

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

  return pumpApp(
    locale: locale,
    overrides: [
      activeProfileIdProvider.overrideWithValue(
        tracks.isNotEmpty ? tracks.first.profileId : _kProfileId,
      ),
      userDatabaseProvider.overrideWith((ref) => database),
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

    // AUD-t-profiles-04: drive the REAL _showDeleteDialog via longPress on
    // the real ParentTrackManagementScreen and read the rendered dialog
    // body Text — not a bare l10n getter — so this test actually fails if
    // _showDeleteDialog is edited to reference the sibling own-profile key
    // (l10n.deleteTrackArchiveBody) instead of the child-scoped one.
    testWidgets('longPress + real archive dialog renders the child-scoped '
        'parentDeleteTrackArchiveBody body, not the own-profile string', (
      tester,
    ) async {
      final db = inMemoryDb();
      await seedProfile(db);
      final trackId = await seedTrack(
        db,
        profileId: _kProfileId,
        curriculumId: 'mishnayos',
      );
      // A second active curriculum keeps the profile above the minimum-1
      // threshold so the dialog offers Archive/Wipe (and therefore
      // renders parentDeleteTrackArchiveBody) instead of the blocking
      // "last curriculum" message.
      await seedTrack(db, profileId: _kProfileId, curriculumId: 'bavli');

      final track = CurriculumTrack(
        id: trackId,
        profileId: _kProfileId,
        curriculumId: 'mishnayos',
        state: 'active',
        stateChangedAt: DateTime.utc(2026, 1, 1),
        activatedAt: DateTime.utc(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildApp(router: router, tracks: [track], db: db),
      );
      await _settle(tester);

      await tester.longPress(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(ParentTrackManagementScreen)),
      )!;

      // The real dialog must render the child-scoped body verbatim.
      expect(
        find.text(l10n.parentDeleteTrackArchiveBody),
        findsOneWidget,
        reason:
            'TS-14: the real archive dialog must render '
            'parentDeleteTrackArchiveBody ("your child\'s completion '
            'history"), not the own-profile deleteTrackArchiveBody.',
      );
      // The own-profile string must NOT appear — this is what catches
      // _showDeleteDialog being swapped to the sibling own-profile key.
      expect(
        find.text(l10n.deleteTrackArchiveBody),
        findsNothing,
        reason:
            'TS-14: the own-profile deleteTrackArchiveBody string must '
            'not appear in the parent-managing-child dialog.',
      );

      await db.close();
      await _teardown(tester);
    });
  });
}
