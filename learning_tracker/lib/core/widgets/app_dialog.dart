/// Shared, overflow-safe dialog primitives for the whole app.
///
/// Every dialog should route through [showAppDialog] (for arbitrary content)
/// or [showAppConfirmDialog] (for the common icon + title + message +
/// confirm/cancel shape). These helpers are overflow-proof *by construction*:
///
///   * The body is **always** wrapped in a [SingleChildScrollView], so content
///     that is taller than the available space scrolls instead of overflowing.
///   * The dialog is height-constrained to the viewport — screen height minus
///     the safe-area insets, minus [MediaQueryData.viewInsets] (the on-screen
///     keyboard), minus a small breathing-room margin. When the keyboard opens
///     or the screen is short, the content shrinks-to-fit and scrolls.
///   * The dialog is width-constrained ([_kMaxWidth]) so it stays readable on
///     tablets / large screens.
///   * Everything is wrapped in [SafeArea] and driven by [MediaQuery], so it
///     adapts to all screen sizes and `textScaleFactor` (large-text a11y).
///
/// Visual style matches the project's branded dialogs (rounded card, brand
/// cream surface, pill-shaped full-width action buttons) — see the historical
/// "Exit Track Setup?" dialog and the reorder confirm dialog.
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Maximum dialog width on large screens / tablets.
const double _kMaxWidth = 480;

/// Horizontal inset between the dialog and the screen edge.
const double _kHorizontalInset = 24;

/// Vertical breathing room kept clear above/below the dialog so it never
/// butts right up against the status bar or a freshly-opened keyboard.
const double _kVerticalMargin = 24;

/// Shows an overflow-safe dialog.
///
/// [builder] returns the dialog *body* (title, fields, etc.). It is placed
/// inside a height-constrained, scrollable, branded card automatically — the
/// caller never has to think about overflow.
///
/// Pass [actions] to render a column of full-width action buttons pinned below
/// the scrollable body (they do not scroll away, but the card as a whole still
/// honours the viewport constraint). If you need the actions to scroll with the
/// content, include them in [builder] instead and omit [actions].
///
/// Mirrors [showDialog]'s contract: returns the value passed to
/// `Navigator.pop`, or `null` if dismissed.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<Widget>? actions,
  bool barrierDismissible = true,
  Color? barrierColor,
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(24, 26, 24, 20),
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.46),
    builder: (context) => _AppDialogShell(
      contentPadding: contentPadding,
      actions: actions,
      body: builder(context),
    ),
  );
}

/// Overflow-safe confirmation dialog: an icon, a title, a message, and a
/// confirm / cancel pair of pill buttons — the exact shape of the old
/// "Exit Track Setup?" dialog.
///
/// Returns `true` when the user confirms, `false` when they cancel or dismiss.
///
/// * [confirmLabel] / [cancelLabel] default to the shared `actionConfirm` /
///   `actionCancel` l10n strings.
/// * [icon] is rendered in a soft circular badge above the title. Defaults to
///   [Icons.help_outline_rounded]. When [destructive] is `true` the badge and
///   confirm button use the danger palette.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  IconData? icon,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (context) => _ConfirmDialogBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

/// The branded, height-constrained, scrollable card that wraps every
/// [showAppDialog]/[showAppConfirmDialog] body.
class _AppDialogShell extends StatelessWidget {
  const _AppDialogShell({
    required this.body,
    required this.contentPadding,
    this.actions,
  });

  final Widget body;
  final EdgeInsets contentPadding;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    // Available height = full screen, minus the system safe-area insets
    // (status bar / notch / nav bar), minus the keyboard (viewInsets.bottom),
    // minus a small margin top & bottom so the card never touches the edges.
    final padding = media.padding;
    final keyboard = media.viewInsets.bottom;
    final maxHeight =
        media.size.height -
        padding.top -
        padding.bottom -
        keyboard -
        (_kVerticalMargin * 2);

    final cardColor = theme.dialogTheme.backgroundColor ?? theme.cardColor;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kHorizontalInset,
            vertical: _kVerticalMargin,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Clamp to a sane positive height even on absurdly small canvases.
              maxHeight: maxHeight > 0 ? maxHeight : media.size.height,
              maxWidth: _kMaxWidth,
            ),
            child: Material(
              color: cardColor,
              elevation: 0,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The body is ALWAYS scrollable + flexible: when content +
                  // actions exceed maxHeight, the body shrinks and scrolls
                  // while the actions stay pinned. This is what makes the
                  // dialog overflow-proof by construction.
                  Flexible(
                    child: SingleChildScrollView(
                      padding: contentPadding,
                      child: body,
                    ),
                  ),
                  if (actions != null && actions!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        contentPadding.left,
                        0,
                        contentPadding.right,
                        contentPadding.bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Body for [showAppConfirmDialog] — icon badge, title, message, and the
/// confirm/cancel pill buttons. Rendered inside [_AppDialogShell], so it is
/// itself overflow-safe.
class _ConfirmDialogBody extends StatelessWidget {
  const _ConfirmDialogBody({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.icon,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    final badgeColor = destructive
        ? AppColors.statusErrorSoft
        : (isDark ? AppTheme.brandBlueDarkContainer : AppTheme.brandBlueSoft);
    final iconColor = destructive
        ? AppColors.chartRed
        : (isDark ? AppTheme.brandBlueDark : AppTheme.brandBlue);
    final confirmColor = destructive ? AppColors.chartRed : AppTheme.brandBlue;

    final titleColor = isDark ? AppTheme.darkInk : AppTheme.brandBlueDeep;
    final messageColor = isDark
        ? AppTheme.darkInkMuted
        : AppTheme.brandInkMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          child: Icon(
            icon ?? Icons.help_outline_rounded,
            color: iconColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: messageColor,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 2,
            ),
            child: Text(confirmLabel ?? l10n.actionConfirm),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppTheme.darkInkMuted
                  : AppTheme.brandInkMuted,
              backgroundColor: isDark
                  ? AppTheme.darkSurfaceSoft
                  : AppColors.dialogCancelButtonBg,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(cancelLabel ?? l10n.actionCancel),
          ),
        ),
      ],
    );
  }
}
