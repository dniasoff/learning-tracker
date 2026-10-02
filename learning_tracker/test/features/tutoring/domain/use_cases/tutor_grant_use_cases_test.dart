// UpdateTutorGrantPermissionsUseCase — AD-53 / DNI-487 (AC-5).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/repositories/tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TutorGrantRepository {}

TutorGrant _grant(TutorGrantState state) {
  final now = DateTime.utc(2026);
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: 'g-1',
      parentUid: 'p',
      childProfileId: 'c',
      tutorEmail: 't@example.com',
      state: state,
      invitedAt: now,
      updatedAt: now,
      acceptedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    ),
    permissions: const TutorPermissions(),
  );
}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  for (final value in [true, false]) {
    test(
      'active grant: forwards canEditLearning=$value to the repository',
      () async {
        when(
          () => repo.updateGrantPermissions(
            grantId: any(named: 'grantId'),
            canEditLearning: any(named: 'canEditLearning'),
          ),
        ).thenAnswer((_) async => const TutorGrantSuccess(grantId: 'g-1'));

        final result = await UpdateTutorGrantPermissionsUseCase(
          repo,
        ).call(grant: _grant(TutorGrantState.active), canEditLearning: value);

        expect(result, isA<TutorGrantSuccess>());
        verify(
          () => repo.updateGrantPermissions(
            grantId: 'g-1',
            canEditLearning: value,
          ),
        ).called(1);
      },
    );
  }

  for (final state in [
    TutorGrantState.pending,
    TutorGrantState.revokedByParent,
    TutorGrantState.expired,
  ]) {
    test('$state grant: precondition error, no callable', () async {
      final result = await UpdateTutorGrantPermissionsUseCase(
        repo,
      ).call(grant: _grant(state), canEditLearning: true);

      expect(result, isA<TutorGrantPreconditionError>());
      expect(
        (result as TutorGrantPreconditionError).code,
        TutorGrantPreconditionCode.cannotUpdatePermissions,
      );
      verifyNever(
        () => repo.updateGrantPermissions(
          grantId: any(named: 'grantId'),
          canEditLearning: any(named: 'canEditLearning'),
        ),
      );
    });
  }
}
