/// TRK-HUB-04: the destructive track actions are gated when only one active
/// curriculum remains. The guard is pure and therefore needs no database.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _Activation extends Mock implements CurriculumActivationService {}

class _Router extends Mock implements StackRouter {}

final _track = CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Widget _app(_Activation activation) => ProviderScope(
  overrides: [
    activeTracksProvider.overrideWith((ref) => Stream.value([_track])),
    curriculumActivationServiceProvider.overrideWithValue(activation),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StackRouterScope(
      controller: _Router(),
      stateHash: 0,
      child: const Scaffold(body: TrackManagementBody()),
    ),
  ),
);

void main() {
  group('TRK-HUB-04: last-curriculum guard', () {
    test('blocks destructive actions for the last active curriculum', () {
      expect(trackDeletionAllowed(activeCurriculumCount: 0), isFalse);
      expect(trackDeletionAllowed(activeCurriculumCount: 1), isFalse);
    });

    test(
      'allows destructive actions when another curriculum remains active',
      () {
        expect(trackDeletionAllowed(activeCurriculumCount: 2), isTrue);
      },
    );

    testWidgets('widget hides destructive actions for the last curriculum', (
      tester,
    ) async {
      final activation = _Activation();
      when(
        activation.getActiveCurricula,
      ).thenAnswer((_) async => [CurriculumId.mishnayos]);
      await tester.pumpWidget(_app(activation));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.longPress(find.byType(InkWell).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete Track'), findsOneWidget);
      expect(
        find.text('At least one curriculum must remain active'),
        findsOneWidget,
      );
      expect(find.text('Archive (keep history)'), findsNothing);
      expect(find.text('Delete and wipe history'), findsNothing);
    });

    testWidgets(
      'widget offers archive and wipe when another curriculum remains',
      (tester) async {
        final activation = _Activation();
        when(
          activation.getActiveCurricula,
        ).thenAnswer((_) async => [CurriculumId.mishnayos, CurriculumId.bavli]);
        await tester.pumpWidget(_app(activation));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.longPress(find.byType(InkWell).first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Archive (keep history)'), findsOneWidget);
        expect(find.text('Delete and wipe history'), findsOneWidget);
      },
    );
  });
}
