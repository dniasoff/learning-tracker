/// Regression test for PP-16 — Profile cards grotesquely tall on tablet/landscape.
///
/// ROOT CAUSE: `ProfileGrid` used to use
/// `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
/// childAspectRatio: 0.67)`. On a wide tablet each column is ~1280 px →
/// card height forced to ~1910 px. The fix is to use
/// `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260)` which
/// caps the column width and lets Flutter add more columns on wide viewports.
///
/// AUD-t-profiles-04: the previous version of this file never imported (or
/// pumped) `ProfileGrid` at all — it re-instantiated
/// `SliverGridDelegateWithMaxCrossAxisExtent`/`WithFixedCrossAxisCount` from
/// scratch and asserted on Flutter's own layout math, so it could not notice
/// `profile_grid.dart`'s `gridDelegate:` argument being changed, removed, or
/// reverted to `FixedCrossAxisCount(2)` — the exact PP-16 bug it claimed to
/// guard. This version pumps the real [ProfileGrid] widget at a wide-tablet
/// viewport and reads the rendered [ProfileCard] tile's actual [RenderBox]
/// size.
///
/// RED behaviour: with FixedCrossAxisCount(2) on a 2560-px viewport, column
/// width = 1273 px → height ≈ 1900 px (grotesque). Verified by temporarily
/// reverting `profile_grid.dart:39` to
/// `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, ...)` — this
/// test fails (tile width/height far exceed the bounds below).
/// GREEN behaviour: with the real `MaxCrossAxisExtent(260)` delegate in
/// production, tile width ≤ 260 px → height ≤ ~390 px (compact).
@Tags(['unit', 'profiles', 'layout', 'pp16'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_card.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_grid.dart';

import '../../../../helpers/pump_app.dart';

List<ProfileModel> _profiles(int count) => List.generate(
  count,
  (i) => ProfileModel(
    id: i + 1,
    accountId: 1,
    displayName: 'Child ${i + 1}',
    mode: 'child',
    avatarIndex: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);

Widget _buildGrid({required List<ProfileModel> profiles}) {
  return pumpApp(
    child: Scaffold(
      body: ProfileGrid(
        profiles: profiles,
        isSelectingProfile: false,
        onProfileTap: (_) {},
        onProfileLongPress: (_, _) {},
        onAddProfile: (_) {},
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PP-16 — ProfileGrid keeps tiles compact on wide-tablet viewports', () {
    testWidgets(
      'PP-16: the real ProfileGrid keeps rendered ProfileCard tile width ≤ 260 '
      'and height ≤ 420 px on a 2560-px-wide viewport',
      (tester) async {
        tester.view.physicalSize = const Size(2560, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildGrid(profiles: _profiles(3)));
        await tester.pumpAndSettle();

        final tileSize = tester.getSize(find.byType(ProfileCard).first);

        // PP-16 fix: MaxCrossAxisExtent(260) must cap the rendered tile's
        // cross-axis width on a 2560-px viewport. The reverted
        // FixedCrossAxisCount(2) delegate gives ~1273 px here.
        expect(
          tileSize.width,
          lessThanOrEqualTo(274), // 260 + crossAxisSpacing(14)
          reason:
              'PP-16 fix: ProfileGrid must cap ProfileCard tile width on a '
              '2560-px viewport. Buggy FixedCrossAxisCount(2) gives ~1287 px.',
        );

        // Tile height ≤ ~420 px (260 / 0.67 ≈ 388 px + slack).
        expect(
          tileSize.height,
          lessThanOrEqualTo(420),
          reason:
              'PP-16 fix: rendered ProfileCard tile height must be ≤ ~420 px. '
              'Buggy delegate gives ~1920 px on a 2560-px tablet.',
        );
      },
    );
  });
}
