import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Design tokens (keep in sync with [parent_pin_keypad_dialog.dart]).
const Color kParentModeDialogNavy = AppTheme.brandInk;
const Color kParentModeDialogMuted = AppTheme.brandInkMuted;

/// White rounded dialog used for parent-mode PIN flows and the add-profile
/// picker — matches the “Enter parent PIN” modal chrome.
///
/// Content scrolls when it would exceed ~88% of viewport height (avoids
/// [RenderFlex] overflow on short screens or with keyboard).
class ParentModeDialogFrame extends StatelessWidget {
  const ParentModeDialogFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.onClose,
    this.showCloseButton = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onClose;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Dialog(
      backgroundColor: AppTheme.brandCreamCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360, maxHeight: maxH),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showCloseButton)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        color: kParentModeDialogMuted,
                        size: 22,
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
                  )
                else
                  const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kParentModeDialogNavy,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kParentModeDialogMuted,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
