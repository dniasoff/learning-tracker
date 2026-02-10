import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
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
