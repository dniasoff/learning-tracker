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
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final e = _emailController.text.trim();
    return e.isNotEmpty && e.contains('@') && e.contains('.');
  }

  Future<void> _sendInvite() async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.inviteTutorSentSnackbar(email),
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        case TutorGrantFailure(:final message):
          setState(() => _errorMessage = message);
        case TutorGrantPreconditionError(:final message):
          setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        backgroundColor: AppTheme.brandCream,
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
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE8E0FF),
                child: Icon(
                  Icons.person_add_rounded,
                  size: 36,
                  color: Color(0xFF6B3FA0),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.inviteTutorHeading,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.inviteTutorBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: const [TrimLeadingSpaceFormatter()],
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.inviteTutorEmailLabel,
                  hintText: l10n.inviteTutorEmailHint,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.email_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC8CCD8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFC8CCD8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.brandBlue,
                      width: 1.5,
                    ),
                  ),
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
                  backgroundColor: AppTheme.brandBlue,
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
