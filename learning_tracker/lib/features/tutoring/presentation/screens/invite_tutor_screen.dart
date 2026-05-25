// W6.7 — Invite tutor screen (parent side) (FR-2.1, FR-2.2)
//
// Parent enters the tutor's email address, then either:
//   (a) Taps "Send invite" → calls InviteTutorUseCase
//   (b) Taps "Generate share link" → shows a copyable deep-link as fallback
//
// The invite flow:
//   1. Validate email
//   2. Call InviteTutorUseCase → repository → Cloud Function
//   3. On success: show the share link + "Copy link" button
//   4. On error: show inline error message
//
// Wire to InviteTutorUseCase (W4.31). The grant repository implementation
// (data layer / Cloud Function call) is not in scope for this UI task;
// the screen calls through the use case and surfaces the result.

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
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
  String? _shareLink; // populated after successful invite

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
      _shareLink = null;
    });
    try {
      final useCase = ref.read(inviteTutorUseCaseProvider);
      final result = await useCase(
        tutorEmail: email,
        childProfileId: widget.childProfileId,
      );
      if (!mounted) return;
      switch (result) {
        case TutorGrantSuccess(:final grantId):
          // Build the share link. The token is embedded in the grantId for now;
          // the Cloud Function will generate a real invite URL in production.
          final link = _buildShareLink(grantId ?? 'pending');
          setState(() => _shareLink = link);
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

  String _buildShareLink(String grantId) {
    // Production: replace with the real deep-link URL from the Cloud Function.
    return 'https://app.learningtracker.app/invite?token=$grantId';
  }

  Future<void> _copyLink() async {
    if (_shareLink == null) return;
    await Clipboard.setData(ClipboardData(text: _shareLink!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.inviteTutorLinkCopied),
        ),
      );
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
              // Share link section (shown after invite is sent)
              if (_shareLink != null) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  l10n.inviteTutorShareLinkHeading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.inviteTutorShareLinkBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8CCD8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _shareLink!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.brandInk,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: l10n.inviteTutorCopyLinkTooltip,
                        onPressed: _copyLink,
                        color: AppTheme.brandBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l10n.inviteTutorCopyShareLink),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandBlueDeep,
                    side: const BorderSide(color: AppTheme.brandBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _copyLink,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
