// UpdateTutorGrantPermissionsRequest — AD-53 / Story 1.25 (DNI-487)
//
// The one typed codec for the `updateTutorGrantPermissions` callable payload
// (ruling B13: `{grantId, canEditLearning: bool}`). The functions side reads
// exactly these two fields; the shared contract fixture
// `functions/test/fixtures/update_tutor_grant_permissions_request.json` is
// asserted against [toWire] by the Dart test and sent verbatim to the
// callable by the emulator test, so both ends agree on the wire shape.

/// Callable name of the parent-only permission update (AD-53).
const String kUpdateTutorGrantPermissionsCallable =
    'updateTutorGrantPermissions';

/// Request for [kUpdateTutorGrantPermissionsCallable].
class UpdateTutorGrantPermissionsRequest {
  const UpdateTutorGrantPermissionsRequest({
    required this.grantId,
    required this.canEditLearning,
  });

  /// The `tutor_grants/{grantId}` document the owning parent is changing.
  final String grantId;

  /// The new value of `permissions.can_edit_learning`.
  final bool canEditLearning;

  /// The callable payload. Only these two keys are ever sent.
  Map<String, Object> toWire() => <String, Object>{
    'grantId': grantId,
    'canEditLearning': canEditLearning,
  };
}
