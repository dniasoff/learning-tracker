// AUD-profiles-14 (SM-4) — TutoredChildrenSection visual regressions.
//
// The former cached-mirror/Drift in-flight-read test was removed: the current
// tutor flow has no local mirror or equivalent Firestore read at that entry
// point. The two visual assertions below remain applicable to the current
// Firestore-backed grant flow.

@Tags(['l1', 'tutoring', 'profiles', 'sm4'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;

import '../../../../helpers/pump_app.dart';

// ── Mocks / fakes ────────────────────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._id);
  final String? _id;
  @override
  String? build() => _id;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

const _kTutorProfileId = 'tutor-profile-sm4';

TutorGrant _activeGrant() {
  final now = DateTimeFactory.nowUtc();
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: 'grant-sm4-001',
      parentUid: 'parent-uid-sm4',
      childProfileId: 'child-profile-sm4',
      tutorEmail: 'tutor-sm4@example.com',
      state: TutorGrantState.active,
      invitedAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
      acceptedAt: now.subtract(const Duration(hours: 12)),
      childName: 'Sm4Child',
    ),
    permissions: TutorPermissions.defaults(),
  );
}

// ── Harness ──────────────────────────────────────────────────────────────────

/// Wraps [TutoredChildrenSection] with a toggle that removes it from the tree
/// — simulating the profile-switcher sheet being swiped/backdrop-dismissed,
/// which unmounts the still-live `_TutoredChildRow` underneath it (the row is
/// intentionally left mounted through the PIN gate + entry-pull per
/// tutored_children_section.dart's `dismissSwitcherSheet` doc comment).
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _sheetMounted = true;

  void dismissSheet() => setState(() => _sheetMounted = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sheetMounted
          ? const TutoredChildrenSection()
          : const SizedBox.shrink(),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── AUD-profiles dark-mode sweep ────────────────────────────────────────
  //
  // The leading icon-tile bg was a hardcoded Color(0xFFE8F4FD) that stayed
  // light in dark while its icon reads brandBlue (LIGHTENS in dark) —
  // measured 2.26:1 in dark. See
  // test/core/theme/darkmode_sweep_contrast_test.dart for the WCAG math.

  Finder leadingIcon() => find.byWidgetPredicate(
    (w) => w is Icon && w.icon == Icons.school_rounded && w.size == 24,
  );

  testWidgets(
    'dark mode: TutoredChildRow icon-tile bg reads '
    'settingsProfileBadgeParentBg (not the old hardcoded 0xFFE8F4FD literal)',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final grant = _activeGrant();

      await tester.pumpWidget(
        pumpApp(
          theme: AppTheme.darkTheme(),
          child: const _Harness(),
          overrides: [
            incomingTutorGrantsProvider.overrideWith((ref) async => [grant]),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(_kTutorProfileId),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sm4Child'), findsOneWidget);

      final container = tester.widget<Container>(
        find
            .ancestor(of: leadingIcon(), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.dark.settingsProfileBadgeParentBg);
      expect(decoration.color, isNot(const Color(0xFFE8F4FD)));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('light mode: TutoredChildRow icon-tile bg stays the original '
      '0xFFE8F4FD (no regression)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final grant = _activeGrant();

    await tester.pumpWidget(
      pumpApp(
        child: const _Harness(),
        overrides: [
          incomingTutorGrantsProvider.overrideWith((ref) async => [grant]),
          selectedProfileIdProvider.overrideWith(
            () => _FixedSelectedProfileId(_kTutorProfileId),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sm4Child'), findsOneWidget);

    final container = tester.widget<Container>(
      find.ancestor(of: leadingIcon(), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0xFFE8F4FD));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
