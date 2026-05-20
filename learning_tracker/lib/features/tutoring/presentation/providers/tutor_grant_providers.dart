// Tutor grant Riverpod providers — W6.7, W6.9, W6.10
//
// Exposes use-case instances for the tutor invite + grant lifecycle.
// The concrete TutorGrantRepository implementation (data layer, Cloud
// Functions callables) is provided via a stub that will be replaced when
// the Cloud Functions client is wired up (out of scope for W6 UI tasks).

import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tutor_grant_providers.g.dart';

// ── Stub repository ─────────────────────────────────────────────────────────

/// Stub implementation of [TutorGrantRepository] used until the Cloud
/// Functions data layer is wired up.
///
/// All mutations return [TutorGrantFailure] with an informational message so
/// the UI can surface it gracefully rather than crashing.
class _StubTutorGrantRepository implements TutorGrantRepository {
  const _StubTutorGrantRepository();

  static const TutorGrantFailure _notImplemented = TutorGrantFailure(
    message:
        'The tutoring backend is not yet connected. '
        'Please check for an app update.',
    code: 'not_implemented',
  );

  @override
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
  }) async => _notImplemented;

  @override
  Future<TutorGrantResult> acceptInvite({required String grantId}) async =>
      _notImplemented;

  @override
  Future<TutorGrantResult> declineInvite({required String grantId}) async =>
      _notImplemented;

  @override
  Future<TutorGrantResult> rescindInvite({required String grantId}) async =>
      _notImplemented;

  @override
  Future<TutorGrantResult> revokeGrant({required String grantId}) async =>
      _notImplemented;

  @override
  Future<TutorGrantResult> resignGrant({required String grantId}) async =>
      _notImplemented;

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => const [];

  @override
  Future<List<TutorGrant>> listOutgoingGrants({
    required String childProfileId,
  }) async => const [];
}

// ── Repository provider ──────────────────────────────────────────────────────

@riverpod
TutorGrantRepository tutorGrantRepository(Ref ref) {
  // TODO(W6-data): replace stub with FirestoreTutorGrantRepository once
  // the Cloud Functions callables client is wired up.
  return const _StubTutorGrantRepository();
}

// ── Use case providers ──────────────────────────────────────────────────────

@riverpod
InviteTutorUseCase inviteTutorUseCase(Ref ref) {
  return InviteTutorUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
AcceptTutorInviteUseCase acceptTutorInviteUseCase(Ref ref) {
  return AcceptTutorInviteUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
DeclineTutorInviteUseCase declineTutorInviteUseCase(Ref ref) {
  return DeclineTutorInviteUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
RevokeTutorGrantUseCase revokeTutorGrantUseCase(Ref ref) {
  return RevokeTutorGrantUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

@riverpod
ResignTutorGrantUseCase resignTutorGrantUseCase(Ref ref) {
  return ResignTutorGrantUseCase(
    ref.watch(tutorGrantRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
}

/// Lists active/pending grants where the current user is the tutor.
@riverpod
Future<List<TutorGrant>> incomingTutorGrants(Ref ref) {
  final repo = ref.watch(tutorGrantRepositoryProvider);
  return repo.listIncomingGrants();
}
