/// Regression test for AUD-tracks-17 (AX-3): [TrackManagementBody]'s leading
/// back-navigation `IconButton` (rendered when `showBackButton: true`)
/// already carried a `tooltip` (`MaterialLocalizations.of(context)
/// .backButtonTooltip`), but per the established AUD-progress-02 /
/// AUD-gamification-04 fix shape, `IconButton(tooltip: ...)` alone does NOT
/// populate `SemanticsData.label` on the current Flutter SDK (3.44.6) —
/// `Tooltip`/`RawTooltip` populate `SemanticsData.tooltip` instead.
/// `find.bySemanticsLabel` / `SemanticsNode.label` only see the `label`
/// field, so a screen-reader user tabbing to this control heard only
/// "button" with no indication it navigates back. The fix additionally sets
/// `Icon(semanticLabel: ...)`, which the framework surfaces as
/// `Semantics(label: ...)`.
@Tags(['tracks', 'a11y'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';
import '../../helpers/pump_app.dart';
import 'setup/helpers/track_hub_test_helpers.dart';

Widget _buildApp({
  required MockStackRouter router,
  required UserDatabase database,
  required List<CurriculumTrack> tracks,
  Locale locale = const Locale('en'),
}) {
  return pumpApp(
    retry: (_, __) => null,
    overrides: [
      activeProfileIdProvider.overrideWithValue(
        tracks.isNotEmpty ? tracks.first.profileId : 1,
      ),
      userDatabaseProvider.overrideWith((ref) => database),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      ...perTrackOverrides(tracks),
      useHebrewTermsProvider.overrideWith(() => HebrewTermsOff()),
    ],
    locale: locale,
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const Scaffold(body: TrackManagementBody(showBackButton: true)),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakePageRouteInfo());
  });

  late MockStackRouter router;

  setUp(() {
    router = MockStackRouter();
    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.maybePop<dynamic>(any<dynamic>()),
    ).thenAnswer((_) async => true);
  });

  group('TrackManagementBody — AUD-tracks-17: back button a11y', () {
    testWidgets('EN: back IconButton exposes a non-empty Semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final database = inMemoryDb();
      addTearDown(database.close);
      final track = buildTrack();

      await tester.pumpWidget(
        _buildApp(router: router, database: database, tracks: [track]),
      );
      await settle(tester);

      final backButton = find.widgetWithIcon(IconButton, Icons.arrow_back);
      expect(backButton, findsOneWidget);

      // AC (literal): a semantics test confirms the back control announces
      // a localized label.
      final semantics = tester.getSemantics(backButton);
      expect(
        semantics.label,
        isNotEmpty,
        reason:
            'AUD-tracks-17: the icon-only back button must expose a '
            'non-empty semantic label so TalkBack/VoiceOver announce its '
            'purpose.',
      );
      expect(semantics.label, 'Back');
      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      handle.dispose();
      await teardown(tester);
    });

    testWidgets(
      'HE: back IconButton exposes the Hebrew MaterialLocalizations label',
      (tester) async {
        final handle = tester.ensureSemantics();
        final database = inMemoryDb();
        addTearDown(database.close);
        final track = buildTrack();

        await tester.pumpWidget(
          _buildApp(
            router: router,
            database: database,
            tracks: [track],
            locale: const Locale('he'),
          ),
        );
        await settle(tester);

        expect(
          find.bySemanticsLabel('הקודם'),
          findsOneWidget,
          reason:
              'AUD-tracks-17: the Hebrew back-button label must be exposed '
              'on the semantics tree, not an English leak.',
        );

        handle.dispose();
        await teardown(tester);
      },
    );
  });
}
