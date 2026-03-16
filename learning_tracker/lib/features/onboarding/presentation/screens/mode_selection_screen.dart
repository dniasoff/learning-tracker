import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';

@RoutePage()
class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  UserMode? _selectedMode;
  bool _isLoading = false;

  Future<void> _confirmSelection() async {
    if (_selectedMode == null) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        if (mounted) {
          unawaited(context.router.replaceAll([const SignInRoute()]));
        }
        return;
      }

      final profileService = ref.read(userProfileServiceProvider);
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: user.displayName ?? '',
        mode: _selectedMode!,
      );

      if (mounted) {
        // Proceed to curriculum selection (onboarding screen placeholder)
        unawaited(context.router.replace(const OnboardingRoute()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save mode. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Mode')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How would you like to use the app?',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can change this later in Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _ModeCard(
              mode: UserMode.child,
              title: 'Child',
              description:
                  'Full gamification, mystery rewards, parent oversight',
              icon: Icons.child_care,
              isSelected: _selectedMode == UserMode.child,
              onTap: _isLoading
                  ? null
                  : () => setState(() => _selectedMode = UserMode.child),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              mode: UserMode.adult,
              title: 'Adult',
              description:
                  'Streamlined tracking, self-directed, optional engagement features',
              icon: Icons.person,
              isSelected: _selectedMode == UserMode.adult,
              onTap: _isLoading
                  ? null
                  : () => setState(() => _selectedMode = UserMode.adult),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _selectedMode != null && !_isLoading
                  ? _confirmSelection
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final UserMode mode;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
