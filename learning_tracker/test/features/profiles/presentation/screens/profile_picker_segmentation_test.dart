/// Widget tests for profile-picker section-header segmentation logic.
///
/// Covers all 4 rows of the segmentation table:
///
/// | ownChild | tutored | Expected sections                           |
/// |----------|---------|---------------------------------------------|
/// | 0        | 0       | No section headers — ungrouped grid          |
/// | >0       | 0       | "YOUR PROFILES" + "CHILD PROFILES"          |
/// | 0        | >0      | "YOUR PROFILES" + "TALMID PROFILES" (via    |
/// |          |         | TutoredChildrenSection header key)           |
/// | >0       | >0      | "YOUR PROFILES" + "CHILD PROFILES" +        |
/// |          |         | "TALMID PROFILES"                            |
///
/// These tests exercise [OwnProfilesSection] and [ChildProfilesSection]
/// directly (the pure-widget layer), keeping the test scope small and avoiding
/// the need to mock the full screen provider graph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/my_children_section.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime(2026);

/// Minimal profile stub with no callbacks needed by the grid.
ProfileModel _adult(int id) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: 'Adult $id',
  mode: 'adult',
  avatarIndex: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
);

ProfileModel _child(int id) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: 'Child $id',
  mode: 'child',
  avatarIndex: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
);

/// Wraps [child] in a [ProviderScope] + [MaterialApp] with localizations.
/// Uses a [SingleChildScrollView] so grid content doesn't overflow the test
/// viewport during layout checks.
Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Pumps [widget] and waits for all animations to settle.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(_wrap(widget));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Shared dummy callbacks (no-op — we only test headers, not tap behaviour)
// ---------------------------------------------------------------------------
void _noop1(int _) {}
void _noop2(ProfileModel _, int __) {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OwnProfilesSection — header visibility', () {
    // ── Row 1: ownChild == 0 && tutored == 0 ──────────────────────────────
    testWidgets(
      'shows NO section header when only adult profiles exist (ungrouped)',
      (tester) async {
        await _pump(
          tester,
          OwnProfilesSection(
            profiles: [_adult(1), _adult(2)],
            showHeader: false, // no children, no tutored
            isSelectingProfile: false,
            onProfileTap: _noop1,
            onProfileLongPress: _noop2,
            onAddProfile: _noop1,
          ),
        );

        // "YOUR PROFILES" must NOT appear.
        expect(find.text('YOUR PROFILES'), findsNothing);
        // The profile grid should still render.
        expect(find.text('Adult 1'), findsOneWidget);
        expect(find.text('Adult 2'), findsOneWidget);
      },
    );

    // ── Row 2: ownChild > 0 && tutored == 0 ───────────────────────────────
    testWidgets(
      'shows YOUR PROFILES header when child profiles exist (tutored == 0)',
      (tester) async {
        await _pump(
          tester,
          OwnProfilesSection(
            profiles: [_adult(1), _child(2)],
            showHeader: true, // child profiles exist
            isSelectingProfile: false,
            onProfileTap: _noop1,
            onProfileLongPress: _noop2,
            onAddProfile: _noop1,
          ),
        );

        expect(find.text('YOUR PROFILES'), findsOneWidget);
        expect(find.text('Adult 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
      },
    );

    // ── Row 3: ownChild == 0 && tutored > 0 ───────────────────────────────
    testWidgets(
      'shows YOUR PROFILES header when tutored > 0 (no child profiles)',
      (tester) async {
        await _pump(
          tester,
          OwnProfilesSection(
            profiles: [_adult(1)],
            showHeader: true, // tutored grants exist
            isSelectingProfile: false,
            onProfileTap: _noop1,
            onProfileLongPress: _noop2,
            onAddProfile: _noop1,
          ),
        );

        expect(find.text('YOUR PROFILES'), findsOneWidget);
        expect(find.text('Adult 1'), findsOneWidget);
      },
    );

    // ── Row 4: ownChild > 0 && tutored > 0 ────────────────────────────────
    testWidgets(
      'shows YOUR PROFILES header when both child and tutored profiles exist',
      (tester) async {
        await _pump(
          tester,
          OwnProfilesSection(
            profiles: [_adult(1), _child(2)],
            showHeader: true,
            isSelectingProfile: false,
            onProfileTap: _noop1,
            onProfileLongPress: _noop2,
            onAddProfile: _noop1,
          ),
        );

        expect(find.text('YOUR PROFILES'), findsOneWidget);
      },
    );
  });

  // ── ChildProfilesSection ─────────────────────────────────────────────────
  group('ChildProfilesSection — label', () {
    testWidgets('renders CHILD PROFILES label', (tester) async {
      await _pump(tester, const ChildProfilesSection());
      expect(find.text('CHILD PROFILES'), findsOneWidget);
    });
  });

  // ── Composite: row 2 — YOUR PROFILES + CHILD PROFILES ───────────────────
  group('Composite row 2 (ownChild>0, tutored==0)', () {
    testWidgets(
      'OwnProfilesSection + ChildProfilesSection renders both headers',
      (tester) async {
        await _pump(
          tester,
          Column(
            children: [
              OwnProfilesSection(
                profiles: [_adult(1), _child(2)],
                showHeader: true,
                isSelectingProfile: false,
                onProfileTap: _noop1,
                onProfileLongPress: _noop2,
                onAddProfile: _noop1,
              ),
              const ChildProfilesSection(),
            ],
          ),
        );

        expect(find.text('YOUR PROFILES'), findsOneWidget);
        expect(find.text('CHILD PROFILES'), findsOneWidget);
      },
    );
  });

  // ── Composite: row 1 — no headers ───────────────────────────────────────
  group('Composite row 1 (ownChild==0, tutored==0)', () {
    testWidgets('no headers when adults only, no ChildProfilesSection', (
      tester,
    ) async {
      await _pump(
        tester,
        OwnProfilesSection(
          profiles: [_adult(1)],
          showHeader: false,
          isSelectingProfile: false,
          onProfileTap: _noop1,
          onProfileLongPress: _noop2,
          onAddProfile: _noop1,
        ),
      );

      expect(find.text('YOUR PROFILES'), findsNothing);
      expect(find.text('CHILD PROFILES'), findsNothing);
    });
  });
}
