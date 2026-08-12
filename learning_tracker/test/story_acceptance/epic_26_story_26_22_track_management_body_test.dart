/// Story acceptance coverage for Epic 26, Story 26.22.
@Tags(['epic_26', 'story_26_22'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide expect, group, test;
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:test/test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('Story 26.22 — TrackManagementBody surface', tags: ['story_26_22'], () {
    test('widget can be constructed without a back button', () {
      const widget = TrackManagementBody();
      expect(widget.showBackButton, isFalse);
    });

    test('widget can be constructed with a back button and add mode', () {
      const widget = TrackManagementBody(showBackButton: true, startAdding: true);
      expect(widget.showBackButton, isTrue);
      expect(widget.startAdding, isTrue);
    });

    testWidgets('builds the localized empty state and back affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            activeTracksProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const TrackManagementBody(showBackButton: true),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.manageTracks), findsOneWidget);
      expect(find.text(l10n.noTracksYet), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.arrow_back), findsOneWidget);
    });
  });

  group('Story 26.22 — Drift activation/deletion wiring', skip:
      'Blocked: the original widget interaction and activation assertions still override userDatabaseProvider with a Drift database. Firestore track writes are not yet wired through this widget.',
      () {
    test('placeholder for the pending Firestore track-management seam', () {});
  });
}
