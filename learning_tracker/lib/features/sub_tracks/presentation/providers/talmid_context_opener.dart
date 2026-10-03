/// How a My talmidim row opens its learner (Story 4.3, DNI-511; AC-3,
/// AC-5, UX-DR-83).
///
/// [PinGatedTalmidContextOpener] is the production path:
/// 1. where the tutor has a Tutor PIN configured, the existing
///    [TutorPinEntryGate] must succeed first; cancel or failure leaves the
///    roster as it was (AC-5);
/// 2. the grant is re-validated live (a grant revoked between the roster
///    render and the tap never enters the learner);
/// 3. the talmid's tutored context is entered and the app lands on his
///    Dashboard — or, for *Add ground*, on that sub-track's ground picker
///    (AC-3).
/// Any unexpected failure fails closed (no context is entered).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show
        TutorPinEntryGate,
        TutoredProfileSelection,
        activeTutoredProfileSelectionProvider,
        tutorPinServiceProvider;

/// Opens a talmid's context from his row: the learner's screens, or with
/// [groundSubTrackId] that sub-track's ground picker (*Add ground*).
abstract interface class TalmidContextOpener {
  /// Opens [entry]; true when the learner's context was entered, false
  /// when it was cancelled or refused (the roster stays as it was).
  Future<bool> open(
    BuildContext context,
    TalmidRosterEntry entry, {
    String? groundSubTrackId,
  });
}

/// How long the live grant check may take before the open is refused.
const Duration talmidGrantCheckTimeout = Duration(seconds: 10);

/// The PIN-gated opener, its steps injected.
final class PinGatedTalmidContextOpener implements TalmidContextOpener {
  /// Creates the opener.
  const PinGatedTalmidContextOpener({
    required this.tutorOwnProfileId,
    required this.hasTutorPin,
    required this.verifyPin,
    required this.grantStillActive,
    required this.enter,
    required this.navigate,
  });

  /// The tutor's OWN learner-profile id: the Tutor PIN namespace (C1).
  final String? Function() tutorOwnProfileId;

  /// Whether a Tutor PIN is configured under that id.
  final Future<bool> Function(String tutorOwnProfileId) hasTutorPin;

  /// Presents the Tutor PIN gate; true once the PIN is verified.
  final Future<bool> Function(BuildContext context, String tutorOwnProfileId)
  verifyPin;

  /// Whether [TalmidRosterEntry]'s grant still authorizes the tutor now.
  final Future<bool> Function(TalmidRosterEntry entry) grantStillActive;

  /// Enters the tutored context.
  final void Function(TutoredProfileSelection selection) enter;

  /// Lands in the entered context ([pinVerified]: the PIN was entered).
  final Future<void> Function(
    TalmidRosterEntry entry, {
    required String tutorOwnProfileId,
    required bool pinVerified,
    String? groundSubTrackId,
  })
  navigate;

  @override
  Future<bool> open(
    BuildContext context,
    TalmidRosterEntry entry, {
    String? groundSubTrackId,
  }) async {
    try {
      final ownId = tutorOwnProfileId();
      if (ownId == null) {
        // No honest PIN namespace to fall back to (AD-24): bail.
        AppLogger.instance.warning(event: 'talmidim_open_no_active_profile');
        return false;
      }
      if (entry.scope == null) return false;
      var pinVerified = false;
      if (await hasTutorPin(ownId)) {
        if (!context.mounted) return false;
        pinVerified = await verifyPin(context, ownId);
        if (!pinVerified) return false;
      }
      if (!await grantStillActive(entry)) return false;
      enter(
        TutoredProfileSelection(
          profileId: entry.profileId,
          ownerUid: entry.ownerUid,
          grantId: entry.grantId,
          permissions: entry.permissions,
          tutorOwnProfileId: ownId,
        ),
      );
      await navigate(
        entry,
        tutorOwnProfileId: ownId,
        pinVerified: pinVerified,
        groundSubTrackId: groundSubTrackId,
      );
      return true;
    } on Object catch (error, stackTrace) {
      AppLogger.instance.error(
        event: 'talmidim_open_failed_closed',
        exception: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

/// The opener rows use: the PIN-gated production path.
final talmidContextOpenerProvider = Provider<TalmidContextOpener>(
  (ref) => PinGatedTalmidContextOpener(
    tutorOwnProfileId: () => ref.read(selectedProfileIdProvider),
    hasTutorPin: (id) => ref.read(tutorPinServiceProvider).hasTutorPin(id),
    verifyPin: _presentTutorPinGate,
    grantStillActive: (entry) => _grantStillActive(ref, entry),
    enter: (selection) => ref
        .read(activeTutoredProfileSelectionProvider.notifier)
        .enter(selection),
    navigate:
        (
          entry, {
          required tutorOwnProfileId,
          required pinVerified,
          groundSubTrackId,
        }) async {
          final router = ref.read(routerProvider);
          if (pinVerified) {
            // The tutor scope is authenticated: the first tutor-scoped
            // route after the gate does not prompt again.
            router.pinGuard.markScopeAuthenticated(
              PinScope.tutor(tutorOwnProfileId),
            );
          }
          await router.replaceAll([
            const AppShellRoute(),
            if (groundSubTrackId != null)
              GroundPickerRoute(subTrackId: groundSubTrackId),
          ]);
        },
  ),
);

Future<bool> _presentTutorPinGate(
  BuildContext context,
  String tutorOwnProfileId,
) async {
  final verified = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (gateContext) => TutorPinEntryGate(
        profileId: tutorOwnProfileId,
        onPinVerified: () => Navigator.of(gateContext).pop(true),
        onCancel: () => Navigator.of(gateContext).pop(false),
      ),
    ),
  );
  return verified ?? false;
}

/// The live grant verdict for [entry]'s learner (the 4.2a grant source).
Future<bool> _grantStillActive(Ref ref, TalmidRosterEntry entry) async {
  final scope = entry.scope;
  if (scope == null) return false;
  final sub = ref.listen(tutorScopeGrantProvider(scope).future, (_, _) {});
  try {
    final verdict = await sub.read().timeout(talmidGrantCheckTimeout);
    return verdict is TutorScopeGranted;
  } on Object {
    return false;
  } finally {
    sub.close();
  }
}
