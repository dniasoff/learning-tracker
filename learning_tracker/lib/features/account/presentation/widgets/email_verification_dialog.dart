import 'package:flutter/material.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_confirm_panel.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the email-verification prompt as a [Dialog] and returns whether the
/// user confirmed they have verified their email.
///
/// Returns `true` if the user tapped "I've verified" and the check succeeded,
/// `false` if they cancelled or the check failed.
Future<bool> showEmailVerificationDialog({
  required BuildContext context,
  required String email,
  required AppLocalizations l10n,
  required Future<void> Function() onSendAgain,
  required Future<bool> Function() onVerified,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final dialogL10n = AppLocalizations.of(dialogContext)!;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: EmailVerificationConfirmPanel(
          email: email,
          bodyText: dialogL10n.authVerifyEmailBody,
          verifiedLinkLabel: dialogL10n.authIveVerified,
          onSendAgain: onSendAgain,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onVerified: () async {
            final verified = await onVerified();
            if (verified && dialogContext.mounted) {
              Navigator.of(dialogContext).pop(true);
            }
          },
        ),
      );
    },
  );
  return result ?? false;
}
