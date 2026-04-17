import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/auth_guard.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/guards/tutor_pin_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Riverpod provider that creates and owns the [AppRouter] singleton.
///
/// Guards are wired to real [PinService] instances so that PIN verification
/// uses secure storage rather than hard-coded stubs.
final routerProvider = Provider<AppRouter>((ref) {
  final pinSvc = ref.watch(pinServiceProvider);

  // Guards resolve the database lazily via getters rather than via a
  // watched field. Sign-in/signup flows invalidate userDatabaseProvider
  // to swap per-account DB files mid-flow — if the router watched the
  // provider, that invalidate would tear down the router, reset its
  // route state, and bounce brand-new sign-ins back to WelcomeRoute.
  UserDatabase getDb() => ref.read(userDatabaseProvider);

  return AppRouter(
    authGuard: AuthGuard(),
    restoreGuard: RestoreGuard(
      getDatabase: getDb,
      hasCloudAccount: () => ref.read(authStateProvider).isCloudBorn,
    ),
    profileGuard: ProfileGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      setSelectedProfileId: (id) =>
          ref.read(selectedProfileIdProvider.notifier).select(id),
      getAccountId: () => ref.read(currentAccountIdProvider),
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
    ),
    parentPinGuard: ParentPinGuard(
      pinService: pinSvc,
      promptForPin: () {
        final context = navigatorKey.currentContext;
        if (context == null) return Future.value(null);
        return _showPinDialog(context, 'Enter Parent PIN');
      },
      getProfileId: () => ref.read(selectedProfileIdProvider),
    ),
    tutorPinGuard: TutorPinGuard(
      pinService: pinSvc,
      promptForPin: () {
        final context = navigatorKey.currentContext;
        if (context == null) return Future.value(null);
        return _showPinDialog(context, 'Enter Tutor PIN');
      },
    ),
  );
});

/// A global navigator key that the app must assign to [MaterialApp.router]
/// so guards can obtain a [BuildContext] for showing PIN dialogs.
final navigatorKey = GlobalKey<NavigatorState>();

/// Shows a modal dialog with a [PinEntryWidget] and returns the entered PIN,
/// or `null` if the user dismissed without submitting.
Future<String?> _showPinDialog(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinDialog(title: title),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: PinEntryWidget(
        title: widget.title,
        onPinComplete: (pin) => Navigator.of(context).pop(pin),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
