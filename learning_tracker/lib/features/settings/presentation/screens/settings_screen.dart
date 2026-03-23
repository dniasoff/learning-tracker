import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/link_provider_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';

// TODO(DNI-105): Replace with dynamic version from package_info_plus
// once the dependency is added to pubspec.yaml.
const String _appVersion = '1.0.0';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(activeCurriculaStreamProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            // User Profile Section
            _UserProfileSection(user: user),
            const Divider(),

            // User Mode Section
            _UserModeSection(user: user),
            const Divider(),

            // Content Language Section
            const _ContentLanguageSection(),
            const Divider(),

            // Active Curricula Section
            const ListTile(
              title: Text(
                'Active Curricula',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text('Choose which curricula to display in the app'),
            ),
            const Divider(),

            activeCurriculaAsync.when(
              data: (activeCurricula) {
                return Column(
                  children: CurriculumId.values.expand((curriculum) {
                    final isActive = activeCurricula.contains(curriculum);
                    return [
                      _CurriculumToggleTile(
                        curriculum: curriculum,
                        isActive: isActive,
                        activeCurriculaCount: activeCurricula.length,
                      ),
                      if (isActive)
                        _CurriculumScopeTile(curriculum: curriculum),
                    ];
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading curricula: $error'),
                ),
              ),
            ),

            // Task 5: Add new curriculum (shown if not all are active)
            activeCurriculaAsync.when(
              data: (activeCurricula) {
                if (activeCurricula.length >= CurriculumId.values.length) {
                  return const SizedBox.shrink();
                }
                return _AddCurriculumTile(activeCurricula: activeCurricula);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const Divider(height: 32),

            // Settings Navigation Links
            const ListTile(
              title: Text(
                'More Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories),
              title: const Text('My Learning Journey'),
              subtitle: const Text('View your lifetime learning achievements'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushRoute(LearningJourneyRoute()),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushRoute(const NotificationsRoute()),
            ),
            ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: const Text('Data & Sync'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushRoute(const SyncRoute()),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Mark Prior Completions'),
              subtitle: const Text('Bulk mark content as already learned'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showBulkMarkCurriculumPicker(context, ref),
            ),

            const Divider(height: 32),

            // Data Export & Import Section
            const ListTile(
              title: Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Export Data'),
              subtitle: const Text('Save all progress to a JSON file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleExportData(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Import Data'),
              subtitle: const Text('Restore progress from a JSON file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleImportData(context, ref),
            ),

            const Divider(height: 32),

            // Account Management Section
            const ListTile(
              title: Text(
                'Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),

            if (user != null &&
                user.providerData.any((info) => info.providerId == 'password'))
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordFlow(context, ref, user),
              ),

            if (user != null)
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Link Account'),
                subtitle: const Text('Add another sign-in method'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLinkProviderDialog(context, ref),
              ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () => _showSignOutConfirmation(context, ref),
            ),

            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _showDeleteAccountFlow(context, ref, user),
            ),

            const Divider(height: 32),

            // App Version
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Version $_appVersion',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays user profile info: display name, email, and auth provider.
class _UserProfileSection extends StatelessWidget {
  const _UserProfileSection({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const ListTile(
        leading: Icon(Icons.person_outline),
        title: Text('Not signed in'),
      );
    }

    final providerIds = user!.providerData.map((p) => p.providerId).toList();
    final providerLabel = providerIds
        .map((id) {
          switch (id) {
            case 'google.com':
              return 'Google';
            case 'password':
              return 'Email/Password';
            default:
              return id;
          }
        })
        .join(', ');

    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(user!.displayName ?? user!.email?.split('@').first ?? 'User'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user!.email != null) Text(user!.email!),
          Text('Signed in with $providerLabel'),
        ],
      ),
      isThreeLine: user!.email != null,
    );
  }
}

/// Displays current user mode with option to change.
class _UserModeSection extends ConsumerStatefulWidget {
  const _UserModeSection({required this.user});

  final User? user;

  @override
  ConsumerState<_UserModeSection> createState() => _UserModeSectionState();
}

class _UserModeSectionState extends ConsumerState<_UserModeSection> {
  UserMode? _currentMode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    if (widget.user == null) return;
    final profileService = ref.read(userProfileServiceProvider);
    final mode = await profileService.getUserMode(widget.user!.uid);
    if (mounted) {
      setState(() {
        _currentMode = mode;
        _loading = false;
      });
    }
  }

  String _modeDisplayName(UserMode mode) =>
      mode.name[0].toUpperCase() + mode.name.substring(1);

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();

    final modeText = _loading
        ? 'Loading...'
        : _currentMode != null
        ? _modeDisplayName(_currentMode!)
        : 'Not set';

    return ListTile(
      leading: Icon(
        _currentMode == UserMode.child ? Icons.child_care : Icons.person,
      ),
      title: const Text('User Mode'),
      subtitle: Text(modeText),
      trailing: const Icon(Icons.chevron_right),
      onTap: _loading ? null : () => _showChangeModeConfirmation(context, ref),
    );
  }

  Future<void> _showChangeModeConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final user = widget.user;
    if (user == null) return;

    final profileService = ref.read(userProfileServiceProvider);
    final currentMode = _currentMode ?? UserMode.adult;
    final newMode = currentMode == UserMode.adult
        ? UserMode.child
        : UserMode.adult;

    final implications = newMode == UserMode.child
        ? 'Switching to Child mode will:\n'
              '• Enable gamification features (points, rewards)\n'
              '• Make parent mode available for parental controls\n'
              '• Show celebratory animations on completions'
        : 'Switching to Adult mode will:\n'
              '• Disable gamification popups and animations\n'
              '• Remove parent mode access\n'
              '• Show streamlined completion confirmations';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Switch to ${_modeDisplayName(newMode)} Mode?'),
        content: Text(implications),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Switch to ${_modeDisplayName(newMode)}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
        mode: newMode,
      );
      if (mounted) {
        setState(() => _currentMode = newMode);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mode changed to ${_modeDisplayName(newMode)}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change mode. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

Future<void> _showBulkMarkCurriculumPicker(
  BuildContext context,
  WidgetRef ref,
) async {
  final activeCurricula = ref.read(activeCurriculaStreamProvider).value;
  if (activeCurricula == null || activeCurricula.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active curricula found.')),
      );
    }
    return;
  }

  if (activeCurricula.length == 1) {
    // Skip picker, go directly to bulk mark
    if (!context.mounted) return;
    await Navigator.of(context).push<BulkMarkResult>(
      MaterialPageRoute<BulkMarkResult>(
        builder: (_) => BulkMarkScreen(curriculumId: activeCurricula.first),
      ),
    );
    return;
  }

  final selected = await showDialog<CurriculumId>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select Curriculum'),
      children: activeCurricula
          .map<Widget>(
            (CurriculumId c) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c.displayNameEn),
            ),
          )
          .toList(),
    ),
  );

  if (selected == null || !context.mounted) return;

  await Navigator.of(context).push<BulkMarkResult>(
    MaterialPageRoute<BulkMarkResult>(
      builder: (_) => BulkMarkScreen(curriculumId: selected),
    ),
  );
}

Future<void> _handleExportData(BuildContext context, WidgetRef ref) async {
  try {
    final service = ref.read(dataExportImportServiceProvider);
    final jsonString = await service.exportData();

    if (!context.mounted) return;

    // Show share dialog with exported data
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Complete'),
        content: Text(
          'Exported ${jsonString.length} bytes of data.\n\n'
          'Use the share button to save the file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleImportData(BuildContext context, WidgetRef ref) async {
  // In a real implementation, this would use file_picker to select a file.
  // For now, we show the import flow structure.
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Import: Select a JSON file to restore data.'),
    ),
  );
}

/// Shows import preview and confirmation dialog.
/// Called after a JSON file is selected and read.
Future<bool> showImportConfirmation({
  required BuildContext context,
  required WidgetRef ref,
  required String jsonString,
}) async {
  final service = ref.read(dataExportImportServiceProvider);

  try {
    final preview = service.validateAndPreview(jsonString);

    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Warning: Importing will overwrite all existing data.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Exported: ${preview.exportedAt}'),
            Text('Version: ${preview.appVersion}'),
            const Divider(),
            Text('Completions: ${preview.completionCount}'),
            Text('Goals: ${preview.goalCount}'),
            Text('Stages: ${preview.stageCount}'),
            Text('Rewards: ${preview.rewardCount}'),
            Text('Streaks: ${preview.streakCount}'),
            Text('Point Configs: ${preview.pointConfigCount}'),
            Text('Bookmarks: ${preview.bookmarkCount}'),
            Text('Learning Order: ${preview.learningOrderCount}'),
            Text('Curricula: ${preview.activeCurriculaCount}'),
            Text('Tracks: ${preview.curriculumTrackCount}'),
            Text('Profiles: ${preview.userProfileCount}'),
            const Divider(),
            Text(
              'Total records: ${preview.totalRecords}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Import & Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    await service.importData(jsonString);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data imported successfully.')),
      );
    }
    return true;
  } on FormatException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid file: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}

Future<void> _showSignOutConfirmation(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text(
        'Are you sure you want to sign out? Your data will be preserved '
        'for when you sign back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final service = ref.read(accountManagementServiceProvider);
    await service.signOut();
    if (context.mounted) {
      await context.router.replaceAll([const WelcomeRoute()]);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sign out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _showDeleteAccountFlow(
  BuildContext context,
  WidgetRef ref,
  User? user,
) async {
  if (user == null) return;

  final service = ref.read(accountManagementServiceProvider);

  final hasPassword = user.providerData.any(
    (info) => info.providerId == 'password',
  );
  final hasGoogle = user.providerData.any(
    (info) => info.providerId == 'google.com',
  );

  var reauthenticated = false;

  if (hasPassword) {
    reauthenticated =
        await showReauthenticateDialog(
          context: context,
          email: user.email ?? '',
          service: service,
        ) ??
        false;
  } else if (hasGoogle) {
    try {
      await service.reauthenticateWithGoogle();
      reauthenticated = true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  if (!reauthenticated || !context.mounted) return;

  final confirmed = await showDeleteAccountDialog(context: context);
  if (confirmed != true || !context.mounted) return;

  try {
    await service.deleteAccount(user.uid);
    if (context.mounted) {
      await context.router.replaceAll([const WelcomeRoute()]);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _showChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final service = ref.read(accountManagementServiceProvider);

  final reauthenticated = await showReauthenticateDialog(
    context: context,
    email: user.email ?? '',
    service: service,
  );
  if (reauthenticated != true || !context.mounted) return;

  final changed = await showChangePasswordDialog(
    context: context,
    service: service,
  );
  if ((changed ?? false) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );
  }
}

Future<void> _showLinkProviderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(accountManagementServiceProvider);
  await showLinkProviderDialog(context: context, service: service);
}

class _CurriculumScopeTile extends ConsumerWidget {
  const _CurriculumScopeTile({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(curriculumScopeSummaryProvider(curriculum));

    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ListTile(
        leading: const Icon(Icons.filter_list, size: 20),
        title: const Text('Learning Scope'),
        subtitle: Text(
          summaryAsync.when(
            data: (s) => s,
            loading: () => 'Loading...',
            error: (_, __) => 'Error',
          ),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        dense: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ScopeSelectionScreen(curriculumId: curriculum),
            ),
          );
        },
      ),
    );
  }
}

class _CurriculumToggleTile extends ConsumerWidget {
  const _CurriculumToggleTile({
    required this.curriculum,
    required this.isActive,
    required this.activeCurriculaCount,
  });

  final CurriculumId curriculum;
  final bool isActive;
  final int activeCurriculaCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(curriculumActivationServiceProvider);
    final isLastActive = isActive && activeCurriculaCount <= 1;

    return SwitchListTile(
      title: Text(curriculum.displayNameEn),
      subtitle: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(color: isActive ? Colors.green : Colors.grey),
      ),
      value: isActive,
      onChanged: isLastActive
          ? null
          : (newValue) async {
              try {
                final wasActive = isActive;
                await service.toggle(curriculum);
                ref.invalidate(isCurriculumActiveProvider(curriculum));
                ref.invalidate(activeTracksProvider(curriculum));
                ref.invalidate(curriculumContentProvider(curriculum));
                // Offer bulk mark when activating a new curriculum
                if (!wasActive && context.mounted) {
                  final shouldBulkMark = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        'Mark prior completions for ${curriculum.displayNameEn}?',
                      ),
                      content: const Text(
                        'Would you like to mark content you\'ve already completed?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Skip'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Mark Now'),
                        ),
                      ],
                    ),
                  );
                  if ((shouldBulkMark ?? false) && context.mounted) {
                    await Navigator.of(context).push<BulkMarkResult>(
                      MaterialPageRoute<BulkMarkResult>(
                        builder: (_) =>
                            BulkMarkScreen(curriculumId: curriculum),
                      ),
                    );
                  }
                }
              } on StateError catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
    );
  }
}

/// Tile that lets users add a new curriculum post-onboarding.
///
/// Shows a picker excluding already-active curricula, then runs the full
/// activation + wizard + bulk mark flow.
class _AddCurriculumTile extends ConsumerWidget {
  const _AddCurriculumTile({required this.activeCurricula});

  final List<CurriculumId> activeCurricula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.add_circle_outline),
      title: const Text('Add a curriculum'),
      subtitle: const Text('Start tracking a new subject'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _onAdd(context, ref),
    );
  }

  Future<void> _onAdd(BuildContext context, WidgetRef ref) async {
    final inactive = CurriculumId.values
        .where((c) => !activeCurricula.contains(c))
        .toList();

    final selected = await showDialog<CurriculumId>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Curriculum'),
        children: inactive
            .map<Widget>(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Text(c.displayNameEn),
              ),
            )
            .toList(),
      ),
    );

    if (selected == null || !context.mounted) return;

    // Activate the curriculum.
    final activationService = ref.read(curriculumActivationServiceProvider);
    await activationService.activate(selected);
    ref.invalidate(activeCurriculaProvider);
    ref.invalidate(isCurriculumActiveProvider(selected));

    if (!context.mounted) return;

    // Launch wizard for the new curriculum.
    final wizardService = ref.read(learningProcessWizardServiceProvider);
    final presets = await wizardService.getPresetsForCurriculum(selected);

    if (!context.mounted) return;

    final wizardResult = await Navigator.of(context)
        .push<LearningProcessWizardResult>(
          MaterialPageRoute(
            builder: (_) => LearningProcessWizardScreen(
              curriculumId: selected,
              presets: presets,
              isChildMode: false,
            ),
          ),
        );

    if (wizardResult != null) {
      final profileId = ref.read(activeProfileIdProvider);
      await wizardService.applyWizardResult(
        wizardResult.wizardResult,
        profileId: profileId,
      );
      ref.invalidate(stageListProvider(selected));
    }

    if (!context.mounted) return;

    // Launch bulk mark.
    await Navigator.of(context).push<BulkMarkResult>(
      MaterialPageRoute(builder: (_) => BulkMarkScreen(curriculumId: selected)),
    );
  }
}

class _ContentLanguageSection extends StatelessWidget {
  const _ContentLanguageSection();

  @override
  Widget build(BuildContext context) {
    // Language preference is stored but not yet wired to content loading.
    // All languages are bundled — future: load language-specific assets.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          title: Text(
            'Content Language',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Text('Language for curriculum content'),
        ),
        ListTile(
          title: const Text('עברית (Hebrew with nikud)'),
          subtitle: const Text('More languages coming soon'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Additional languages coming in a future update'),
              ),
            );
          },
        ),
      ],
    );
  }
}
