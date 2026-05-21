/// Widget tests for profile-picker section-header segmentation logic.
///
/// Rule (owner-confirmed, 2026-05-21):
///   - The "YOUR PROFILES" header (and the sibling "TALMID PROFILES" header
///     rendered by TutoredChildrenSection) appear **only** when the current
///     user has ≥ 1 active tutored grant — i.e. is a rebbe with talmidim.
///   - Otherwise the picker shows a single flat list with no headers.
///   - Within "YOUR PROFILES", child and adult profiles are co-mingled inside
///     one grid — there is no separate "CHILD PROFILES" sub-section.
///
/// Segmentation table:
///
/// | tutored | Expected header inside OwnProfilesSection |
/// |---------|-------------------------------------------|
/// | 0       | No header (ungrouped grid, no matter how many own children) |
/// | >0      | "YOUR PROFILES" header                    |
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

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(_wrap(widget));
  await tester.pumpAndSettle();
}

void _noop1(int _) {}
void _noop2(ProfileModel _, int __) {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('OwnProfilesSection — header visibility', () {
    testWidgets('NO header when tutored == 0 — adults only (flat list)', (
      tester,
    ) async {
      await _pump(
        tester,
        OwnProfilesSection(
          profiles: [_adult(1), _adult(2)],
          showHeader: false,
          isSelectingProfile: false,
          onProfileTap: _noop1,
          onProfileLongPress: _noop2,
          onAddProfile: _noop1,
        ),
      );

      expect(find.text('YOUR PROFILES'), findsNothing);
      expect(find.text('Adult 1'), findsOneWidget);
      expect(find.text('Adult 2'), findsOneWidget);
    });

    testWidgets(
      'NO header when tutored == 0 — even with child profiles present '
      '(flat list, children co-mingled with adults)',
      (tester) async {
        await _pump(
          tester,
          OwnProfilesSection(
            profiles: [_adult(1), _child(2)],
            showHeader: false,
            isSelectingProfile: false,
            onProfileTap: _noop1,
            onProfileLongPress: _noop2,
            onAddProfile: _noop1,
          ),
        );

        // No headers — child profiles are not bucketed separately.
        expect(find.text('YOUR PROFILES'), findsNothing);
        expect(find.text('CHILD PROFILES'), findsNothing);
        // Both profiles render in the grid.
        expect(find.text('Adult 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
      },
    );

    testWidgets('shows YOUR PROFILES header when tutored > 0', (tester) async {
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
      // No inner CHILD PROFILES sub-section — children co-mingled.
      expect(find.text('CHILD PROFILES'), findsNothing);
      expect(find.text('Adult 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
    });
  });
}
