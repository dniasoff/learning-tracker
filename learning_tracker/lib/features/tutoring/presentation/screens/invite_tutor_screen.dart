// W6.7 — Invite tutor screen (parent side) (FR-2.1, FR-2.2)
//
// Parent enters the tutor's email address and taps "Send invite", which calls
// InviteTutorUseCase.
//
// The invite flow:
//   1. Validate email
//   2. Call InviteTutorUseCase → repository → Cloud Function
//   3. On success: show a confirmation snackbar
//   4. On error: show inline error message
//
// Wire to InviteTutorUseCase (W4.31). The grant repository implementation
// (data layer / Cloud Function call) is not in scope for this UI task;
// the screen calls through the use case and surfaces the result.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Screen where a parent invites a tutor for a specific child profile.
///
/// [childProfileId] — the Drift integer ID of the child profile to share.
@RoutePage()
class InviteTutorScreen extends ConsumerStatefulWidget {
  const InviteTutorScreen({required this.childProfileId, super.key});

  final String childProfileId;

  @override
  ConsumerState<InviteTutorScreen> createState() => _InviteTutorScreenState();
}

class _InviteTutorScreenState extends ConsumerState<InviteTutorScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  /// Account-level error (e.g. "cloud account required"), shown as a banner
  /// above the form — NOT as email-field errorText, which would imply the
  /// address is malformed.
  String? _accountError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Loose but real email shape check — a single `@` with non-empty local part
  /// and a dotted domain whose TLD is at least two chars. Catches "notanemail"
  /// (no `@`), "a@b" (no dot in domain) and "a@b." (empty TLD) while accepting
  /// ordinary addresses.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  bool get _emailValid => _emailPattern.hasMatch(_emailController.text.trim());

  /// P2: inline validation feedback. Empty stays clear (Send simply disabled),
  /// but a typed-but-invalid email shows a localized inline error so the parent
  /// is told WHY Send is disabled instead of the button silently doing nothing.
  void _onEmailChanged() {
    final e = _emailController.text.trim();
    setState(() {
      _errorMessage = (e.isEmpty || _emailValid)
          ? null
          : AppLocalizations.of(context)!.inviteTutorInvalidEmail;
    });
  }

  Future<void> _sendInvite() async {
    // LOCAL-ONLY precondition: inviting a tutor requires a cloud account.
    // Show a clear, non-retryable message instead of letting the attempt
    // fail with a confusing generic error.
    final authState = ref.read(authStateProvider);
    if (authState.isLocalBorn) {
      setState(
        () => _accountError = AppLocalizations.of(
          context,
        )!.inviteTutorErrorLocalOnly,
      );
      return;
    }

    final email = _emailController.text.trim();
    if (!_emailValid) {
      setState(
        () => _errorMessage = AppLocalizations.of(
          context,
        )!.inviteTutorInvalidEmail,
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _accountError = null;
    });
    try {
      // Snapshot human-readable names onto the grant so the tutor sees the
      // child's name (and inviting parent) instead of a raw id / generic label.
      final profiles = ref.read(profileListProvider).asData?.value ?? const [];
      final childIdInt = int.tryParse(widget.childProfileId);
      final childName = profiles
          .where((p) => p.id == childIdInt)
          .map((p) => p.displayName)
          .firstOrNull;
      final parentName = profiles
          .where((p) => p.profileMode == ProfileMode.adult)
          .map((p) => p.displayName)
          .firstOrNull;

      final useCase = ref.read(inviteTutorUseCaseProvider);
      final result = await useCase(
        tutorEmail: email,
        childProfileId: widget.childProfileId,
        childName: childName,
        parentName: parentName,
      );
      if (!mounted) return;
      switch (result) {
        case TutorGrantSuccess():
          // Refresh the (non-autoDispose, cached) outgoing-grants list so the
          // new pending invite shows up immediately on Manage Tutors instead
          // of serving the stale empty result fetched before this invite.
          ref.invalidate(outgoingTutorGrantsProvider(widget.childProfileId));
          // Show the confirmation on the root messenger so it survives the
          // pop, then return to Manage Tutors — previously the screen stayed
          // put with no navigation, so the tap appeared to do nothing.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.inviteTutorSentSnackbar(email),
              ),
              backgroundColor: context.colors.statusSuccessSnackbar,
            ),
          );
          await Navigator.of(context).maybePop();
          return;
        case TutorGrantFailure(:final message, :final code):
          // Never surface the raw backend error token (e.g. "Unauthenticated",
          // a Firebase/gRPC status string) to the parent. Map it to a friendly,
          // localized message — mirrors the ST-4 pattern in backup_sync_section.
          setState(
            () => _errorMessage = _friendlyInviteError(
              AppLocalizations.of(context)!,
              code: code,
              message: message,
            ),
          );
        case TutorGrantPreconditionError(:final code):
          setState(
            () => _errorMessage = _preconditionErrorMessage(
              code,
              AppLocalizations.of(context)!,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Map a backend invite failure to a friendly, localized message so raw
  /// status tokens (e.g. the gRPC/Firebase string "Unauthenticated") never
  /// reach the parent. Unauthenticated / permission errors get a sign-in
  /// hint; everything else gets a generic friendly fallback.
  String _friendlyInviteError(
    AppLocalizations l10n, {
    String? code,
    required String message,
  }) {
    final token = '${code ?? ''} $message'.toLowerCase();
    final isAuthError =
        token.contains('unauthenticated') ||
        token.contains('permission-denied') ||
        token.contains('permission_denied') ||
        token.contains('permission denied');
    return isAuthError
        ? l10n.inviteTutorErrorUnauthenticated
        : l10n.inviteTutorErrorGeneric;
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
      TutorGrantPreconditionCode.invalidTutorEmail =>
        l10n.inviteTutorInvalidEmail,
      TutorGrantPreconditionCode.cannotAccept ||
      TutorGrantPreconditionCode.cannotDecline ||
      TutorGrantPreconditionCode.cannotRescind ||
      TutorGrantPreconditionCode.cannotRevoke ||
      TutorGrantPreconditionCode.cannotResign => l10n.inviteTutorErrorGeneric,
    };
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
        title: Text(l10n.inviteTutorAppBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 36,
                backgroundColor: context.colors.tutorPinBadgeBg,
                child: Icon(
                  Icons.person_add_rounded,
                  size: 36,
                  color: context.colors.tutorPinBadgeIcon,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.inviteTutorHeading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colors.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.inviteTutorBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.colors.brandInkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // Account-level notice (e.g. "cloud account required").
              // Shown as a banner so it is not confused with email validation.
              if (_accountError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _accountError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: const [TrimLeadingSpaceFormatter()],
                textInputAction: TextInputAction.done,
                onChanged: (_) => _onEmailChanged(),
                decoration: InputDecoration(
                  labelText: l10n.inviteTutorEmailLabel,
                  hintText: l10n.inviteTutorEmailHint,
                  prefixIcon: const Icon(Icons.email_rounded),
                  errorText: _errorMessage,
                ),
              ),
              const SizedBox(height: 20),
              // Send invite button
              FilledButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isLoading ? l10n.inviteTutorSending : l10n.inviteTutorSend,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: (_isLoading || !_emailValid) ? null : _sendInvite,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
