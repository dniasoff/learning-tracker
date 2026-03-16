import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(activeCurriculaStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Change Mode Section
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Change Mode'),
            subtitle: const Text('Switch between Child and Adult mode'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangeModeDialog(context, ref),
          ),
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

          // Show loading or error states
          activeCurriculaAsync.when(
            data: (activeCurricula) {
              return Column(
                children: CurriculumId.values.map((curriculum) {
                  final isActive = activeCurricula.contains(curriculum);
                  return _CurriculumToggleTile(
                    curriculum: curriculum,
                    isActive: isActive,
                    activeCurriculaCount: activeCurricula.length,
                  );
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
        ],
      ),
    );
  }
}

Future<void> _showChangeModeDialog(BuildContext context, WidgetRef ref) async {
  final user = ref.read(firebaseAuthProvider).currentUser;
  if (user == null) return;

  final profileService = ref.read(userProfileServiceProvider);
  final currentMode = await profileService.getUserMode(user.uid);

  if (!context.mounted) return;

  final selected = await showDialog<UserMode>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select Mode'),
      children: UserMode.values.map((mode) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, mode),
          child: ListTile(
            leading: Icon(
              mode == UserMode.child ? Icons.child_care : Icons.person,
            ),
            title: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
            trailing: mode == currentMode
                ? const Icon(Icons.check, color: Colors.green)
                : null,
          ),
        );
      }).toList(),
    ),
  );

  if (selected == null || selected == currentMode || !context.mounted) return;

  try {
    await profileService.setUserMode(
      firebaseUid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
      mode: selected,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mode changed to ${selected.name[0].toUpperCase()}${selected.name.substring(1)}',
          ),
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
          ? null // Disable toggle for last active curriculum
          : (newValue) async {
              try {
                await service.toggle(curriculum);
                // Invalidate family providers for the toggled curriculum (P3)
                ref.invalidate(isCurriculumActiveProvider(curriculum));
                ref.invalidate(activeTracksProvider(curriculum));
                ref.invalidate(curriculumContentProvider(curriculum));
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
