import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Action buttons for the sign-in screen:
/// - Primary sign-in (email/password) button with loading state
/// - Google sign-in button (online only)
/// - "New here? Register" rich-text link
class SignInActions extends StatefulWidget {
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
  State<SignInActions> createState() => _SignInActionsState();
}

class _SignInActionsState extends State<SignInActions> {
  // AUD-account-21: created once here (not in build()) and disposed in
  // dispose() below. InlineSpan/TextSpan does not manage the lifetime of its
  // recognizer, so a StatelessWidget that allocated a new one on every
  // build() would leak one recognizer per rebuild. The onTap closure reads
  // `widget.isLoading` / `widget.onRegister` (not captured locals) so it
  // always observes the current widget config across rebuilds.
  late final TapGestureRecognizer _registerTapRecognizer;

  @override
  void initState() {
    super.initState();
    _registerTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        if (!widget.isLoading) widget.onRegister();
      };
  }

  @override
  void dispose() {
    _registerTapRecognizer.dispose();
    super.dispose();
  }

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
              // AUD-darkmode: brandBlue/brandBlueBright are ACCENT roles
              // that intentionally LIGHTEN in dark mode, but this CTA paints
              // them as a gradient FILL with hardcoded white text/spinner --
              // in dark mode the gradient washed out to pale sky-blue,
              // measured 1.85:1 against the bright end. signInCtaGradient*
              // are pinned to the exact old brandBlue/brandBlueBright light
              // literals in both themes, restoring 5.62-8.41:1.
              gradient: LinearGradient(
                colors: [
                  context.colors.signInCtaGradientStart,
                  context.colors.signInCtaGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: context.colors.brandBlueBright.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: widget.isLoading ? null : widget.onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.transparent,
                shadowColor: context.colors.transparent,
                foregroundColor: Colors.white,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.l10n.signInCta,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        if (widget.isOnline) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: widget.isLoading ? null : widget.onGoogleSignIn,
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: Text(widget.l10n.signInWithGoogleCta),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.brandInk,
              side: BorderSide(color: context.colors.brandInkSoft),
            ),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 18),
        Center(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.colors.brandInkMuted,
              ),
              children: [
                TextSpan(text: widget.l10n.signInNewToQuest),
                TextSpan(
                  text: widget.l10n.signInRegisterHere,
                  style: TextStyle(
                    color: context.colors.brandBlue,
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: _registerTapRecognizer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
