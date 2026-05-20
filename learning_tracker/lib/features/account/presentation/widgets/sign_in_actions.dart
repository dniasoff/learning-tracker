import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Action buttons for the sign-in screen:
/// - Primary sign-in (email/password) button with loading state
/// - Google sign-in button (online only)
/// - "New here? Register" rich-text link
class SignInActions extends StatelessWidget {
  const SignInActions({
    super.key,
    required this.isLoading,
    required this.isOnline,
    required this.l10n,
    required this.onSignIn,
    required this.onGoogleSignIn,
    required this.onRegister,
  });

  final bool isLoading;
  final bool isOnline;
  final AppLocalizations l10n;

  final VoidCallback onSignIn;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.brandBlue, AppTheme.brandBlueBright],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandBlueBright.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: isLoading ? null : onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.transparent,
                shadowColor: AppTheme.transparent,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brandCreamCard,
                      ),
                    )
                  : Text(
                      l10n.signInCta,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        if (isOnline) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogleSignIn,
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: Text(l10n.signInWithGoogleCta),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 18),
        Center(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
              children: [
                TextSpan(text: l10n.signInNewToQuest),
                TextSpan(
                  text: l10n.signInRegisterHere,
                  style: const TextStyle(
                    color: Color(0xFF8E6425),
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      if (!isLoading) onRegister();
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
