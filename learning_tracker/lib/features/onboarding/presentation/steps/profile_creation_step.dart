import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart'
    show showNikudPrefProvider;
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/auth/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

export 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart'
    show OnboardingStep, OnboardingStepContext;

/// Returns child-aware text based on profile mode.
///
/// In adult mode, returns [adultText]. In child mode, replaces `{name}`
/// in [childTemplate] with [childName].
String childAwareText(
  String adultText,
  String childTemplate,
  String? childName, {
  bool isChildMode = false,
}) {
  if (!isChildMode || childName == null) return adultText;
  return childTemplate.replaceAll('{name}', childName);
}

// SharedPreferences keys for onboarding state persistence
const kOnboardingPhaseKey = 'onboarding_phase';
const kOnboardingProfileIdKey = 'onboarding_profile_id';
const kOnboardingProfileNameKey = 'onboarding_profile_name';
const kOnboardingProfileModeKey = 'onboarding_profile_mode';

/// Persistent flag — once set, onboarding is never shown again on this device.
const kOnboardingComplete = 'onboarding_complete';

/// Mutable model holding profile-creation data shared across steps.
///
/// The [OnboardingScreen] owns a single instance and passes it to the steps
/// that need it, keeping steps themselves stateless with respect to shared
/// onboarding data.
class OnboardingProfileData extends ChangeNotifier {
  String profileMode = 'adult';
  int? createdProfileId;
  String? profileName;
  bool showNikud = true;

  bool get isChildMode => profileMode == 'child';
}

/// Step 1: collect the learner's name, mode, and nikud preference, then
/// create the profile row.
///
/// This is a full [ConsumerStatefulWidget] because it owns TextEditingController
/// state and performs async profile creation.
class ProfileCreationStep extends OnboardingStep {
  const ProfileCreationStep({required this.data});

  /// Shared mutable model updated when the profile is created.
  final OnboardingProfileData data;

  @override
  String get id => 'profileCreation';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _ProfileCreationStepWidget(data: data, ctx: ctx);
  }
}

class _ProfileCreationStepWidget extends ConsumerStatefulWidget {
  const _ProfileCreationStepWidget({required this.data, required this.ctx});

  final OnboardingProfileData data;
  final OnboardingStepContext ctx;

  @override
  ConsumerState<_ProfileCreationStepWidget> createState() =>
      _ProfileCreationStepWidgetState();
}

class _ProfileCreationStepWidgetState
    extends ConsumerState<_ProfileCreationStepWidget> {
  final _nameController = TextEditingController();
  String? _nameError;
  bool _isCreatingProfile = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateProfileName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateProfileName);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateProfileName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (_nameError != null) setState(() => _nameError = null);
      return;
    }

    final profiles = await ref
        .read(profileRepositoryProvider)
        .getProfilesByAccount(ref.read(currentAccountIdProvider));
    final isDuplicate = profiles.any(
      (p) => p.displayName.trim().toLowerCase() == name.toLowerCase(),
    );

    if (!mounted) return;
    setState(() {
      _nameError = isDuplicate
          ? 'A profile with this name already exists'
          : null;
    });
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _nameError != null || _isCreatingProfile) return;
    setState(() => _isCreatingProfile = true);

    await ref.read(showNikudPrefProvider.notifier).set(widget.data.showNikud);

    final repo = ref.read(profileRepositoryProvider);
    final accountId = ref.read(currentAccountIdProvider);
    final ProfileModel profile;
    try {
      profile = await repo.createProfile(
        accountId: accountId,
        displayName: name,
        mode: widget.data.profileMode,
        avatarIndex: 0,
      );
    } on DuplicateProfileNameException {
      if (mounted) {
        setState(() {
          _nameError = 'A profile with this name already exists';
          _isCreatingProfile = false;
        });
      }
      return;
    }

    // Cloud-born only: sync learner mode to the Firestore-backed user doc.
    final authState = ref.read(authStateProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    if (authState.isCloudBorn && user != null) {
      final profileService = ref.read(userProfileServiceProvider);
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: name,
        mode: widget.data.profileMode == 'child'
            ? UserMode.child
            : UserMode.adult,
      );
    }

    widget.data
      ..createdProfileId = profile.id
      ..profileName = name;
    ref.read(selectedProfileIdProvider.notifier).select(profile.id);

    await PendingLocalSignupStore.finalizeAfterFirstProfile(ref);

    if (!mounted) return;
    setState(() => _isCreatingProfile = false);

    // Advance to next step (pin setup for child, add track for adult).
    await widget.ctx.advance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cardRadius = 20.0;
    const prefsBg = Color(0xFFF0F1F6);

    Widget pillPair({
      required String leftLabel,
      required String rightLabel,
      required bool leftSelected,
      required VoidCallback onLeft,
      required VoidCallback onRight,
    }) {
      Widget pill(String label, bool selected, VoidCallback onTap) {
        return Expanded(
          child: Material(
            color: selected ? Colors.white : const Color(0xFFE4E7EF),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandInk,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE4E7EF),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            pill(leftLabel, leftSelected, onLeft),
            const SizedBox(width: 4),
            pill(rightLabel, !leftSelected, onRight),
          ],
        ),
      );
    }

    Widget modeCard({
      required bool isChild,
      required IconData icon,
      required Color iconBgMuted,
      required String title,
      required String subtitle,
    }) {
      final selected = widget.data.profileMode == (isChild ? 'child' : 'adult');
      final iconColor = selected ? AppTheme.brandBlue : AppTheme.brandInkMuted;
      final circleBg = selected
          ? AppTheme.brandBlueSoft.withValues(alpha: 0.85)
          : iconBgMuted;
      return Expanded(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              elevation: selected ? 0 : 1,
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: () => setState(
                  () => widget.data.profileMode = isChild ? 'child' : 'adult',
                ),
                borderRadius: BorderRadius.circular(cardRadius),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: selected ? AppTheme.brandBlue : Colors.transparent,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: circleBg,
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppTheme.brandBlue
                              : AppTheme.brandInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: -6,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD14A4A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What should we call you?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.25,
                color: AppTheme.brandInk,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter name',
                filled: true,
                fillColor: Colors.white,
                errorText: _nameError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFC8CCD8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFC8CCD8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppTheme.brandBlue,
                    width: 1.5,
                  ),
                ),
                suffixIcon: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.brandBlue,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22),
            Text(
              'Learning Experience',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.25,
                color: AppTheme.brandInk,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                modeCard(
                  isChild: true,
                  icon: Icons.rocket_launch_rounded,
                  iconBgMuted: const Color(0xFFE8E0FF),
                  title: 'Child Mode',
                  subtitle: 'Fun & Rewards',
                ),
                const SizedBox(width: 12),
                modeCard(
                  isChild: false,
                  icon: Icons.menu_book_rounded,
                  iconBgMuted: const Color(0xFFE4E7EF),
                  title: 'Adult Mode',
                  subtitle: 'Deep & Scholarly',
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: prefsBg,
                borderRadius: BorderRadius.circular(cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.text_fields_rounded,
                        size: 22,
                        color: AppTheme.brandInk,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nikud',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  pillPair(
                    leftLabel: 'Without nikud',
                    rightLabel: 'With nikud',
                    leftSelected: !widget.data.showNikud,
                    onLeft: () => setState(() => widget.data.showNikud = false),
                    onRight: () => setState(() => widget.data.showNikud = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                elevation: 3,
                shadowColor: AppTheme.brandBlue.withValues(alpha: 0.35),
              ),
              onPressed:
                  _nameController.text.trim().isNotEmpty &&
                      _nameError == null &&
                      !_isCreatingProfile
                  ? _createProfile
                  : null,
              child: _isCreatingProfile
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Profile',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can change these settings anytime later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2 (child mode only): set the parent PIN.
class ParentPinSetupStep extends OnboardingStep {
  const ParentPinSetupStep({required this.data});

  final OnboardingProfileData data;

  @override
  String get id => 'parentPinSetup';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _ParentPinSetupStepWidget(data: data, ctx: ctx);
  }
}

class _ParentPinSetupStepWidget extends ConsumerStatefulWidget {
  const _ParentPinSetupStepWidget({required this.data, required this.ctx});

  final OnboardingProfileData data;
  final OnboardingStepContext ctx;

  @override
  ConsumerState<_ParentPinSetupStepWidget> createState() =>
      _ParentPinSetupStepWidgetState();
}

class _ParentPinSetupStepWidgetState
    extends ConsumerState<_ParentPinSetupStepWidget> {
  String? _firstPin;
  String? _pinError;
  bool _isPinConfirmStep = false;

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _isPinConfirmStep = true;
      _pinError = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _pinError = 'PINs do not match';
        _isPinConfirmStep = false;
        _firstPin = null;
      });
      return;
    }
    final profileId = widget.data.createdProfileId;
    if (profileId == null) return;

    try {
      await ref.read(pinServiceProvider).setProfilePin(profileId, pin);
    } on ArgumentError catch (e) {
      setState(() {
        _pinError = e.message as String?;
        _isPinConfirmStep = false;
        _firstPin = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _firstPin = null;
      _isPinConfirmStep = false;
      _pinError = null;
    });

    await widget.ctx.advance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childName = widget.data.profileName ?? 'your child';
    final subtitle = _isPinConfirmStep
        ? 'Re-enter the PIN to confirm'
        : 'Set a 4-digit PIN to access parent controls for $childName. '
              'The PIN is stored only on this device.';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                PinEntryWidget(
                  title: _isPinConfirmStep ? 'Confirm PIN' : 'Enter New PIN',
                  errorMessage: _pinError,
                  onPinComplete: _isPinConfirmStep
                      ? _onConfirmPinEntered
                      : _onFirstPinEntered,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget shown in the AppBar for the parent PIN step.
class ParentPinSetupAppBarTitle extends StatelessWidget {
  const ParentPinSetupAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBarTitle(text: 'Set Parent PIN');
  }
}
