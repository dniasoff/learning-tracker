// core/widgets/app_error_view.dart — W7.17
//
// Category-mapped error UI for AsyncValue.error states.
//
// AppErrorView replaces the pattern:
//   `if (snap.hasError) Center(child: Text(l10n.errorWithMessage(e.toString())))`
//
// It maps the 5 AppException category bases to distinct UI affordances so the
// user sees an actionable message rather than a raw exception string:
//
//   ValidationException  — form-error summary (no retry — user must act)
//   NetworkException     — offline indicator + retry button
//   PermissionException  — "you don't have access" + sign-in/contact action
//   NotFoundException    — empty-state with optional retry
//   ConflictException    — "something went wrong" with bug-report affordance
//   InternalException    — "something went wrong" with bug-report affordance
//   everything else      — same as InternalException

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// A widget that renders an [AsyncValue.error] as a category-appropriate UI.
///
/// Usage:
/// ```dart
/// someProvider.when(
///   data: (_) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => AppErrorView(error: e, stackTrace: st, onRetry: ref.refresh),
/// )
/// ```
///
/// Or from a widget body:
/// ```dart
/// final snapshot = ref.watch(someProvider);
/// if (snapshot.hasError) {
///   return AppErrorView.fromAsyncValue(snapshot, onRetry: () => ref.refresh(someProvider));
/// }
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  /// The error object — typically from `AsyncValue.error`.
  final Object error;

  /// Optional stack trace (unused in UI but reserved for future crash-report
  /// affordance).
  final StackTrace? stackTrace;

  /// Optional retry callback.  Pass `() => ref.refresh(provider)` from the
  /// calling widget.  When null, no retry button is shown.
  final VoidCallback? onRetry;

  /// Convenience constructor that unpacks an [AsyncValue] with an error.
  ///
  /// Returns null if the value has no error.
  static Widget? fromAsyncValue(
    AsyncValue<dynamic> value, {
    Key? key,
    VoidCallback? onRetry,
  }) {
    if (!value.hasError) return null;
    return AppErrorView(
      key: key,
      error: value.error!,
      stackTrace: value.stackTrace,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _configFor(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: 64, color: config.iconColor(theme)),
            const SizedBox(height: 16),
            Text(
              config.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              config.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (config.showRetry && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
            if (!config.showRetry && config.showBugReport) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Bug-report affordance — no-op placeholder until a real
                  // reporting flow is wired in a later task.
                },
                child: const Text('Report this issue'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static _ErrorConfig _configFor(Object error) {
    if (error is NetworkException) {
      return const _ErrorConfig(
        icon: Icons.wifi_off_outlined,
        title: 'No connection',
        subtitle: 'Check your internet connection and try again.',
        showRetry: true,
        showBugReport: false,
        severity: _Severity.warning,
      );
    }
    if (error is ValidationException) {
      return _ErrorConfig(
        icon: Icons.error_outline,
        title: 'Invalid data',
        subtitle: error.message,
        showRetry: false,
        showBugReport: false,
        severity: _Severity.warning,
      );
    }
    if (error is PermissionException) {
      return const _ErrorConfig(
        icon: Icons.lock_outline,
        title: 'Access denied',
        subtitle:
            "You don't have permission to view this. Sign in or contact support.",
        showRetry: false,
        showBugReport: false,
        severity: _Severity.warning,
      );
    }
    if (error is NotFoundException) {
      return const _ErrorConfig(
        icon: Icons.search_off_outlined,
        title: 'Not found',
        subtitle: 'The requested item could not be found.',
        showRetry: true,
        showBugReport: false,
        severity: _Severity.warning,
      );
    }
    // ConflictException, InternalException, and everything else → generic.
    return const _ErrorConfig(
      icon: Icons.bug_report_outlined,
      title: 'Something went wrong',
      subtitle: 'An unexpected error occurred. Try again or report the issue.',
      showRetry: true,
      showBugReport: true,
      severity: _Severity.error,
    );
  }
}

// ─── Internal config helpers ──────────────────────────────────────────────────

enum _Severity { warning, error }

class _ErrorConfig {
  const _ErrorConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.showRetry,
    required this.showBugReport,
    required _Severity severity,
  }) : _sev = severity;

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showRetry;
  final bool showBugReport;
  final _Severity _sev;

  Color iconColor(ThemeData theme) => switch (_sev) {
    _Severity.warning => theme.colorScheme.tertiary,
    _Severity.error => theme.colorScheme.error,
  };
}
