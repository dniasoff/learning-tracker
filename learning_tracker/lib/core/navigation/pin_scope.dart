import 'package:freezed_annotation/freezed_annotation.dart';

part 'pin_scope.freezed.dart';

/// Identifies which PIN namespace a guarded route requires.
///
/// One [PinGuard] instance is parameterised by a [PinScope] at navigation
/// time — `parent(profileId)` for parent-mode routes, `tutor(profileId)` for
/// tutor-mode routes. Each scope is verified against an independent PIN hash
/// in [PinService] so authenticating the parent scope does not grant tutor
/// access for the same profile (and vice versa).
@freezed
sealed class PinScope with _$PinScope {
  /// Parent-mode PIN scoped to a single child [profileId].
  const factory PinScope.parent(int profileId) = PinScopeParent;

  /// Tutor-mode PIN scoped to a single child [profileId].
  const factory PinScope.tutor(int profileId) = PinScopeTutor;
}
