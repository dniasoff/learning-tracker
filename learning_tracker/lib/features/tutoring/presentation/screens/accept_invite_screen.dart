// W6.9 — Accept invite deep-link flow (FR-2.4)
//
// Entry point for the accept-invite flow. Handles:
//   1. Token validation (parse from incoming URL)
//   2. Auth gate: if not signed in, routes to sign-in/sign-up first
//   3. Grant activation: calls AcceptTutorInviteUseCase with the token
//   4. Tutor PIN check: if no PIN set, routes to TutorPinSetupScreen (W6.4)
//   5. On success: navigates to the dashboard / profile picker
//
// Deep-link entry: the router delivers this screen when the app opens with
// a URI matching `/invite?token=<grantId>`.
//
// Auth flow for unsigned-in users:
//   • The accept-invite URI is persisted in SharedPreferences.
//   • After sign-in/sign-up, the router re-delivers the invite URI, which
//     triggers this screen again. The token is re-read from the URI.
//
// NOTE: The token supplied here is the grantId from Firestore. The Cloud
// Function validates ownership + expiry server-side. The client performs
// a precondition check (grant.canAccept) using the locally loaded TutorGrant
// aggregate before making the round-trip.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
// AUD-tutoring-03: incomingTutorGrantsProvider is the offline-first
// FutureProvider defined here (manage_tutors_providers.dart) — the one the
// tutored-children UI (profile-picker / Settings / ManageGrants) actually
// watches. It no longer collides with a same-named provider in
// tutor_grant_providers.dart (that duplicate was deleted), so this import no
// longer needs an alias to disambiguate.
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Screen that handles the "accept tutor invite" deep-link.
///
/// [token] is the grant ID / invite token extracted from the deep-link URI.
/// The deep-link URL shape is `/invite?token=<grantId>` (query parameter, not
/// a path segment), so the `@QueryParam('token')` annotation is required for
/// auto_route's code generator to wire the query string into this field.
@RoutePage()
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({@QueryParam('token') this.token, super.key});

  /// Invite token (grant id) from the `?token=` query param. Nullable because
  /// auto_route requires @QueryParam fields to be nullable or defaulted; a
  /// null/empty token means a malformed link and is handled as an error.
  final String? token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

enum _AcceptStep {
  /// Waiting for auth check and grant load.
  loading,

  /// Auth confirmed; ready to show accept confirmation.
  readyToAccept,

  /// Acceptance in progress.
  accepting,

  /// PIN setup required before the grant is usable.
  pinSetup,

  /// Grant successfully accepted.
  success,

  /// Something went wrong.
  error,
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  _AcceptStep _step = _AcceptStep.loading;
  String? _errorMessage;
  String? _tutorProfileId;

  // WS3.3b: real grant loaded from incomingTutorGrantsProvider during init.
  // Null if the grant is not yet in the cached list (e.g. first load).
  TutorGrant? _loadedGrant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    // A null/empty token means the deep-link was malformed (no ?token=…).
    final token = widget.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _step = _AcceptStep.error);
      return;
    }

    // Auth check: if not signed in, redirect to sign-in and persist token.
    final authState = ref.read(authStateProvider);
    if (!authState.isSignedIn) {
      if (!mounted) return;
      // Push sign-in screen; on return, this screen will be re-entered via
      // the router re-delivering the deep-link.
      unawaited(
        context.router.push(const SignInRoute()).then((_) {
          if (mounted) unawaited(_initialize());
        }),
      );
      return;
    }

    // C4: resolve the tutor's OWN profile id (AD-24 ULID) — the namespace
    // under which the Tutor PIN is stored/verified (matches C1). No honest
    // fallback exists for a profile-less tutor (there is no ULID "0"), so
    // this is treated the same as the malformed-token case above rather
    // than fabricating one.
    _tutorProfileId = ref.read(selectedProfileIdProvider);
    if (_tutorProfileId == null) {
      if (!mounted) return;
      setState(() => _step = _AcceptStep.error);
      return;
    }

    // WS3.3b: Load the real grant from the incoming grants provider.
    // The token IS the grantId — look it up in the already-loaded list.
    // Falls back to a minimal grant object if not yet in the cached list
    // (the Cloud Function validates ownership and state server-side anyway).
    try {
      final grants = await ref.read(incomingTutorGrantsProvider.future);
      _loadedGrant = grants
          .where((g) => g.grantId == token)
          .cast<TutorGrant?>()
          .firstOrNull;
    } catch (_) {
      // Network unavailable — continue with null; accept will use grantId only.
      _loadedGrant = null;
    }

    if (!mounted) return;
    setState(() => _step = _AcceptStep.readyToAccept);
  }

  Future<void> _acceptInvite() async {
    setState(() => _step = _AcceptStep.accepting);
    try {
      final useCase = ref.read(acceptTutorInviteUseCaseProvider);

      // WS3.3b: use the real grant loaded from the provider if available;
      // fall back to a minimal stub that satisfies the canAccept precondition.
      // The Cloud Function validates ownership and state server-side.
      final token = widget.token;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _step = _AcceptStep.error);
        return;
      }
      final grant = _loadedGrant ?? _buildStubGrant(token);

      final result = await useCase(grant: grant);
      if (!mounted) return;
      switch (result) {
        case TutorGrantSuccess():
          // SEV-2: the CF has flipped this grant pending → active server-side.
          // Invalidate the grant-list providers NOW so every surface that reads
          // them (profile-picker / Settings "TALMID PROFILES" / ManageGrants)
          // re-fetches and the row flips from "Pending — tap to accept" to
          // "Tutoring" IN-SESSION — without requiring a force-stop + cold
          // restart. This is the single funnel all accept entry points pass
          // through (deep link, Settings, profile-picker), so invalidating here
          // fixes the stale row regardless of how acceptance was initiated.
          ref.invalidate(incomingTutorGrantsProvider);
          ref.invalidate(pendingTutorInvitesProvider);
          // C4: check whether the tutor has provisioned a Tutor PIN yet, keyed
          // on their OWN profile id (resolved in _initialize). If not, route to
          // Tutor PIN setup before completing.
          // Guaranteed non-null: _initialize returns early (to
          // _AcceptStep.error) whenever it resolves null, and this method
          // only runs once _step has advanced past that point.
          final profileId = _tutorProfileId!;
          final pinService = ref.read(tutorPinServiceProvider);
          final hasPin = await pinService.hasTutorPin(profileId);
          if (!mounted) return;
          if (!hasPin) {
            setState(() => _step = _AcceptStep.pinSetup);
            return;
          }
          setState(() => _step = _AcceptStep.success);
        case TutorGrantFailure():
          // Never surface raw Firebase/gRPC codes (e.g. "UNAVAILABLE") to
          // the user — always map to a friendly, localized message.
          setState(() {
            _step = _AcceptStep.error;
            _errorMessage = AppLocalizations.of(
              context,
            )!.acceptInviteGenericError;
          });
        case TutorGrantPreconditionError(:final code):
          setState(() {
            _step = _AcceptStep.error;
            _errorMessage = _preconditionErrorMessage(
              code,
              AppLocalizations.of(context)!,
            );
          });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _AcceptStep.error;
          _errorMessage = AppLocalizations.of(
            context,
          )!.acceptInviteGenericError;
        });
      }
    }
  }

  /// AUD-tutoring-02 (EH-5): resolve a [TutorGrantPreconditionCode] to a
  /// localized, user-facing message. [TutorGrantPreconditionError] carries a
  /// stable code, never a pre-formatted message — this exhaustive switch is
  /// the single place that maps each code to user-facing text.
  String _preconditionErrorMessage(
    TutorGrantPreconditionCode code,
    AppLocalizations l10n,
  ) {
    return switch (code) {
      TutorGrantPreconditionCode.cannotAccept =>
        l10n.acceptInvitePreconditionError,
      TutorGrantPreconditionCode.invalidTutorEmail ||
      TutorGrantPreconditionCode.cannotDecline ||
      TutorGrantPreconditionCode.cannotRescind ||
      TutorGrantPreconditionCode.cannotRevoke ||
      TutorGrantPreconditionCode.cannotResign => l10n.acceptInviteGenericError,
    };
  }

  /// Build a minimal stub grant from the raw token for the use-case call.
  ///
  /// The real implementation loads the grant from Firestore so the aggregate
  /// has accurate state + expiry data for the precondition check.
  TutorGrant _buildStubGrant(String grantId) {
    final now = DateTimeFactory.nowUtc();
    final doc = TutorGrantDoc(
      grantId: grantId,
      parentUid: '',
      childProfileId: '',
      tutorEmail: '',
      state: TutorGrantState.pending,
      invitedAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );
    return TutorGrant.fromDoc(doc);
  }

  /// C3: navigate to the decline flow. Uses the loaded grant when available so
  /// DeclineInviteScreen can fire the DEC-23 notification with real grant data;
  /// otherwise passes the raw token (the screen builds a stub + the Cloud
  /// Function validates server-side).
  Future<void> _openDecline(BuildContext context) async {
    final grant = _loadedGrant;
    await context.router.push(
      DeclineInviteRoute(
        grant: grant,
        token: grant == null ? widget.token : null,
        onDeclined: () =>
            unawaited(context.router.replaceAll([const AppShellRoute()])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.brandCream,
      appBar: AppBar(
        backgroundColor: context.colors.brandCream,
        elevation: 0,
        title: Text(l10n.acceptInviteAppBarTitle),
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_step) {
      _AcceptStep.loading => const Center(child: CircularProgressIndicator()),
      _AcceptStep.accepting => _buildAccepting(),
      _AcceptStep.readyToAccept => _buildReadyToAccept(theme),
      _AcceptStep.pinSetup => _buildPinSetup(),
      _AcceptStep.success => _buildSuccess(theme),
      _AcceptStep.error => _buildError(theme),
    };
  }

  Widget _buildAccepting() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.acceptInviteAccepting),
        ],
      ),
    );
  }

  Widget _buildReadyToAccept(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // TUT-03: wrap in LayoutBuilder + SingleChildScrollView + ConstrainedBox so
    // the layout scrolls (instead of overflowing with a RenderFlex error) on
    // short / keyboard-visible viewports. A flexible (not fixed) spacer pushes
    // the actions to the bottom only when there is spare room; under
    // ConstrainedBox(minHeight) it collapses to zero so the content stays
    // intrinsically sized and scrollable. (IntrinsicHeight cannot be used here
    // because it cannot measure an Expanded/Spacer child.)
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight - 48).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: context.colors.tutorPinBadgeBg,
                  child: Icon(
                    Icons.handshake_rounded,
                    size: 36,
                    color: context.colors.tutorPinBadgeIcon,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.acceptInviteHeading,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.brandInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadedGrant == null
                      ? l10n.acceptInviteBody
                      : l10n.acceptInviteBodyFromParentForChild(
                          _loadedGrant!.parentName ?? l10n.tutorFallbackParent,
                          _loadedGrant!.childDisplayLabel,
                        ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.colors.brandInkMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _PermissionRow(
                  icon: Icons.check_circle_rounded,
                  text: l10n.acceptInvitePermissionViewData,
                ),
                // WS3.3h: corrected copy — reflects actual default permission
                // set. Default grant allows bulk-mark + optional
                // track/point/reward editing (canBulkPriorCompletion: true per
                // G3/DEC-33; edit flags set by parent).
                _PermissionRow(
                  icon: Icons.check_circle_rounded,
                  text: l10n.acceptInvitePermissionConfigure,
                ),
                _PermissionRow(
                  icon: Icons.check_circle_rounded,
                  text: l10n.acceptInvitePermissionBulkMark,
                ),
                _PermissionRow(
                  icon: Icons.cancel_rounded,
                  color: context.colors.statusErrorCardText,
                  text: l10n.acceptInvitePermissionNoLive,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _acceptInvite,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l10n.acceptInviteAccept),
                ),
                const SizedBox(height: 10),
                TextButton(
                  // C3: route to the real decline flow — DeclineInviteScreen
                  // calls DeclineTutorInviteUseCase (changes server state) and
                  // fires the DEC-23 parent-notification path. Pass the loaded
                  // grant when available; otherwise fall back to the raw token.
                  onPressed: () => unawaited(_openDecline(context)),
                  child: Text(
                    l10n.acceptInviteDecline,
                    style: TextStyle(color: context.colors.brandInkMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinSetup() {
    return TutorPinSetupScreen(
      // Guaranteed non-null — see the comment in _acceptInvite.
      profileId: _tutorProfileId!,
      onPinSet: () => setState(() => _step = _AcceptStep.success),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Centred fixed pile — wrap in a height-clamped scroll view so it stays
    // vertically centred on normal screens but scrolls (rather than
    // overflowing) on short viewports / large text.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight - 48).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: context.colors.statusSuccessSoftBg,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: context.colors.statusSuccessSoftText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.acceptInviteSuccessHeading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.acceptInviteSuccessBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.colors.brandInkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => unawaited(
                      context.router.replaceAll([const AppShellRoute()]),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.actionGoToDashboard),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    // Centred fixed pile — wrap in a height-clamped scroll view so it stays
    // vertically centred on normal screens but scrolls (rather than
    // overflowing) on short viewports / large text.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight - 48).clamp(0.0, double.infinity)
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: context.colors.statusErrorCardBg,
                    child: Icon(
                      Icons.error_rounded,
                      size: 48,
                      color: context.colors.statusErrorCardText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.acceptInviteErrorHeading,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? l10n.unexpectedError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.colors.brandInkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _step = _AcceptStep.readyToAccept),
                    child: Text(l10n.actionTryAgain),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? context.colors.statusActiveBadge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
