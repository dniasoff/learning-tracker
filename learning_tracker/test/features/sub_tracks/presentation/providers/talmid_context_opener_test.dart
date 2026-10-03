// Story 4.3 (DNI-511) T4: the PIN-gated opener fails closed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_context_opener.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../talmidim_fixtures.dart';

void main() {
  late List<String> steps;

  PinGatedTalmidContextOpener opener({
    Future<bool> Function(String)? hasTutorPin,
  }) => PinGatedTalmidContextOpener(
    tutorOwnProfileId: () => 'tutor-own',
    hasTutorPin: hasTutorPin ?? (_) async => false,
    verifyPin: (_, _) async => true,
    grantStillActive: (_) async => true,
    enter: (_) => steps.add('enter'),
    navigate:
        (
          entry, {
          required tutorOwnProfileId,
          required pinVerified,
          groundSubTrackId,
        }) async => steps.add('navigate'),
  );

  setUp(() => steps = []);

  Future<BuildContext> contextOf(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    return tester.element(find.byType(SizedBox));
  }

  testWidgets('a failing PIN check enters nothing', (tester) async {
    final context = await contextOf(tester);
    final opened = await opener(
      hasTutorPin: (_) async => throw StateError('secure storage'),
    ).open(context, talmidEntry(1));
    expect(opened, isFalse);
    expect(steps, isEmpty);
  });

  testWidgets('a grant naming no addressable learner never opens', (
    tester,
  ) async {
    final context = await contextOf(tester);
    final opened = await opener().open(
      context,
      const TalmidRosterEntry(
        grantId: 'g',
        ownerUid: 'owner',
        profileId: 'not-a-ulid',
        permissions: TutorPermissions(),
      ),
    );
    expect(opened, isFalse);
    expect(steps, isEmpty);
  });

  testWidgets('an addressable learner with no PIN opens', (tester) async {
    final context = await contextOf(tester);
    expect(await opener().open(context, talmidEntry(1)), isTrue);
    expect(steps, ['enter', 'navigate']);
  });
}
