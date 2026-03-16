import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';

/// Main tutor mode screen — read-only view of student data.
///
/// Entering this screen activates tutor mode (read-only enforcement).
/// Exiting deactivates it. Provides access to change tutor PIN.
@RoutePage()
class TutorModeScreen extends ConsumerStatefulWidget {
  const TutorModeScreen({super.key});

  @override
  ConsumerState<TutorModeScreen> createState() => _TutorModeScreenState();
}

class _TutorModeScreenState extends ConsumerState<TutorModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tutorModeProvider.notifier).enter();
    });
  }

  void _exitTutorMode() {
    ref.read(tutorModeProvider.notifier).exit();
    context.router.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isTutorMode = ref.watch(tutorModeProvider);
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(tutorModeProvider.notifier).exit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tutor Mode'),
          actions: [
            if (isTutorMode)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Read Only',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: ListView(
          children: [
            Container(
              color: theme.colorScheme.tertiaryContainer,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tutor mode is read-only. You can view student progress but cannot make changes.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Student Dashboard'),
              subtitle: const Text(
                'View completion history, chazara queue, and progress',
              ),
              onTap: () => context.router.push(const TutorDashboardRoute()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Tutor PIN'),
              subtitle: const Text('Update your tutor access PIN'),
              onTap: () => context.router.push(const TutorPinChangeRoute()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Exit Tutor Mode'),
              onTap: _exitTutorMode,
            ),
          ],
        ),
      ),
    );
  }
}
