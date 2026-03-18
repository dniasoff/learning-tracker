import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';

@RoutePage()
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: SafeArea(
        child: profilesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (profiles) => _PickerBody(profiles: profiles),
        ),
      ),
    );
  }
}

class _PickerBody extends ConsumerWidget {
  final List<ProfileModel> profiles;

  const _PickerBody({required this.profiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Text(
            "Who's learning today?",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return _ProfileCard(
                  profile: profile,
                  onTap: () {
                    ref
                        .read(selectedProfileIdProvider.notifier)
                        .select(profile.id);
                    context.router.replace(const AppShellRoute());
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfileAvatar(avatarIndex: profile.avatarIndex, radius: 36),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                profile.mode == 'child' ? 'Child' : 'Adult',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
