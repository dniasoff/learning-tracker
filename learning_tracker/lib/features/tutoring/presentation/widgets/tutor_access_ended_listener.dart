/// Shows the revoked-session outcome (Story 4.4, DNI-512, T3/T7; UX-DR-136).
///
/// Mounted once in the app shell. When [tutorAccessEndedProvider] publishes
/// a notice it:
/// 1. shows "Access to {name} has ended." in a SnackBar — the app's
///    accessible status surface (a live region, so screen readers announce
///    it) — with no retry action that could re-open the learner;
/// 2. returns to the tutor's roster with [tutorRosterReturnProvider], which
///    replaces the whole stack: an open form, ground picker or Learn tab of
///    the revoked learner is disposed and its unsaved input discarded. The
///    roster route's AppBar title names the route, so screen-reader focus
///    lands on its heading;
/// 3. drops keyboard focus from any control of the closed screens and
///    acknowledges the notice.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_access_ended_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Returns the tutor to his roster of active learners, replacing the stack.
typedef TutorRosterReturn = void Function(BuildContext context);

/// The roster the tutor returns to after access ends.
///
/// [ASSUMPTION] Until Story 4.3's My talmidim route (DNI-511) is on the
/// integration branch, the tutor's roster is the existing My grants list
/// (`/tutor/my-grants`), which already follows the live active-grant set.
/// DNI-511's merge points this one seam at `MyTalmidimRoute`.
final tutorRosterReturnProvider = Provider<TutorRosterReturn>(
  (ref) =>
      (context) => context.router.replaceAll(const [
        AppShellRoute(),
        ManageGrantsRoute(),
      ]),
);

/// The access-ended copy for [notice]: names the learner when known.
String tutorAccessEndedMessage(AppLocalizations l10n, TutorAccessEnded notice) {
  final name = notice.learnerName;
  return name == null || name.isEmpty
      ? l10n.tutorAccessEndedUnnamed
      : l10n.tutorAccessEnded(name);
}

/// Listens for [tutorAccessEndedProvider] around [child] (see library doc).
class TutorAccessEndedListener extends ConsumerWidget {
  /// Creates the listener.
  const TutorAccessEndedListener({super.key, required this.child});

  /// The shell content.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arms the live revocation watch of the open tutored session.
    ref.listen<void>(tutorSessionAccessWatchProvider, (_, _) {});
    ref.listen<TutorAccessEnded?>(tutorAccessEndedProvider, (_, notice) {
      if (notice == null) return;
      final l10n = AppLocalizations.of(context)!;
      final message = tutorAccessEndedMessage(l10n, notice);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const Key('tutorAccessEndedSnackBar'),
            content: Text(message),
          ),
        );
      ref.read(tutorRosterReturnProvider)(context);
      FocusManager.instance.primaryFocus?.unfocus();
      ref.read(tutorAccessEndedProvider.notifier).acknowledge(notice);
    });
    return child;
  }
}
