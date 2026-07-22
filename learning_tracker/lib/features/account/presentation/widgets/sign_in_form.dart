import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Form fields for the sign-in screen: email, password, keep-signed-in.
///
/// This widget is purely presentational — it owns no state. The parent
/// [SignInScreen] supplies controllers, validators, and change/submit callbacks.
class SignInForm extends StatelessWidget {
  const SignInForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.keepSignedIn,
    required this.registrySubtitle,
    required this.l10n,
    required this.onEmailChanged,
    required this.onPasswordToggle,
    required this.onKeepSignedInChanged,
    required this.onSubmit,
    required this.validateEmail,
    required this.validatePassword,
    this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final bool keepSignedIn;

  /// Optional subtitle shown under the email field after registry lookup.
  final String? registrySubtitle;
  final AppLocalizations l10n;

  final ValueChanged<String> onEmailChanged;
  final VoidCallback onPasswordToggle;
  final ValueChanged<bool?> onKeepSignedInChanged;
  final VoidCallback onSubmit;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  /// AN-11: optional callback invoked when the user taps "Forgot password?".
  /// When null the link is omitted (e.g. local-born accounts have no cloud reset).
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLabel(context, l10n.signInYourEmail),
          const SizedBox(height: 8),
          _buildAuthField(
            context,
            controller: emailController,
            hintText: l10n.signInEmailHint,
            prefixIcon: Icons.mail_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: validateEmail,
            onChanged: onEmailChanged,
          ),
          if (registrySubtitle != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
              child: Text(
                registrySubtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.brandInkMuted,
                ),
              ),
            ),
          const SizedBox(height: 20),
          _buildLabel(context, l10n.signInPasswordLabel),
          const SizedBox(height: 8),
          _buildAuthField(
            context,
            controller: passwordController,
            hintText: l10n.signInPasswordHint,
            prefixIcon: Icons.lock_rounded,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            validator: validatePassword,
            onFieldSubmitted: (_) => onSubmit(),
            suffixIcon: IconButton(
              tooltip: obscurePassword ? l10n.showPassword : l10n.hidePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: context.colors.brandInkMuted,
              ),
              onPressed: onPasswordToggle,
            ),
          ),
          // AN-11: "Forgot password?" link — only shown when a callback is
          // provided (cloud accounts). Local-born accounts have argon2id
          // passwords with no server-side reset, so the link is suppressed.
          if (onForgotPassword != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.brandBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.signInForgotPassword,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 14),
          MergeSemantics(
            child: Row(
              children: [
                Checkbox(
                  value: keepSignedIn,
                  onChanged: isLoading ? null : onKeepSignedInChanged,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  l10n.signInKeepMeSignedIn,
                  style: TextStyle(
                    color: context.colors.brandInkMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.brandInk,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Widget _buildAuthField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    bool enabled = true,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: [
        if (obscureText)
          const NoSpaceFormatter()
        else
          const TrimLeadingSpaceFormatter(),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: context.colors.brandInkMuted,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(prefixIcon, color: context.colors.brandInkMuted),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.brandOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.brandOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.brandBlueBright),
        ),
      ),
    );
  }
}
