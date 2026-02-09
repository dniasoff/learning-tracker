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
    final activeCurriculaAsync = ref.watch(activeCurriculaProvider);
    final service = ref.watch(curriculumActivationServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Active Curricula',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle curricula on/off. At least one must remain active.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          activeCurriculaAsync.when(
            data: (activeCurricula) {
              return Column(
                children: CurriculumId.values.map((curriculum) {
                  final isActive = activeCurricula.contains(curriculum);
                  return SwitchListTile(
                    title: Text(curriculum.displayNameEn),
                    subtitle: Text(curriculum.displayNameHe),
                    value: isActive,
                    onChanged: (value) async {
                      try {
                        if (value) {
                          // TODO: Show import progress UI when DNI-31 is complete
                          await service.activate(curriculum);
                        } else {
                          await service.deactivate(curriculum);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading curricula: $error')),
          ),
        ],
      ),
    );
  }
}
