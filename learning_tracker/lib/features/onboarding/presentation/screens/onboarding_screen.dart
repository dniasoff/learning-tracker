import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Slim onboarding phases — global settings only.
///
/// Per-track configuration is delegated to [AddTrackFlow] (Story 18.1).
enum _ScreenPhase {
  profileCreation,
  languageSelection,
  calendarPreference,
  addTrack,
  addAnotherPrompt,
  handoff,
  done,
}

// SharedPreferences keys for onboarding state persistence
const _kOnboardingPhase = 'onboarding_phase';
const _kOnboardingProfileId = 'onboarding_profile_id';
const _kOnboardingProfileName = 'onboarding_profile_name';
const _kOnboardingProfileMode = 'onboarding_profile_mode';
const _kOnboardingLanguage = 'onboarding_language';

/// Persistent flag — once set, onboarding is never shown again on this device.
const kOnboardingComplete = 'onboarding_complete';

/// Supported content languages.
const _supportedLanguages = <String, String>{
  'he': 'עברית (Hebrew with nikud)',
  'he_plain': 'עברית (Hebrew without nikud)',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
};

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String _selectedLanguage = 'he';
  var _phase = _ScreenPhase.profileCreation;

  // Profile creation state
  final _nameController = TextEditingController();
  String _profileMode = 'adult';
  int? _createdProfileId;
  String? _profileName;
  String? _nameError; // Inline validation error for duplicate names

  // Track count for "add another" prompt
  int _trackCount = 0;
  String? _lastTrackLabel;

  bool get _isChildMode => _profileMode == 'child';

  @override
  void initState() {
    super.initState();
    _tryResumeFromSavedState();
    _nameController.addListener(_validateProfileName);
    // Epic 20.6: onboarding is only reachable after signup. If the
    // user somehow lands here without a live AuthState session
    // (signedOut / initializing fallthrough), bounce them back to
    // the welcome screen so they can sign up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (!authState.isSignedIn) {
        unawaited(context.router.replaceAll([const WelcomeRoute()]));
      }
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateProfileName);
    _nameController.dispose();
    super.dispose();
  }

  /// Check the entered name against existing profiles (case-insensitive).
  Future<void> _validateProfileName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (_nameError != null) setState(() => _nameError = null);
      return;
    }

    final profiles = await ref
        .read(profileRepositoryProvider)
        .getProfilesByAccount(1);
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

  // ── State Persistence ──────────────────────────────────────────────────────

  Future<void> _tryResumeFromSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kOnboardingPhase);
    if (savedPhase == null) return;

    final profileId = prefs.getInt(_kOnboardingProfileId);
    final profileName = prefs.getString(_kOnboardingProfileName);
    final profileMode = prefs.getString(_kOnboardingProfileMode);
    final savedLanguage = prefs.getString(_kOnboardingLanguage);

    if (profileId != null) _createdProfileId = profileId;
    if (profileName != null) _profileName = profileName;
    if (profileMode != null) _profileMode = profileMode;
    if (savedLanguage != null) _selectedLanguage = savedLanguage;

    final phase = _ScreenPhase.values.where((p) => p.name == savedPhase);
    if (phase.isNotEmpty && mounted) {
      setState(() => _phase = phase.first);
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOnboardingPhase, _phase.name);
    if (_createdProfileId != null) {
      await prefs.setInt(_kOnboardingProfileId, _createdProfileId!);
    }
    if (_profileName != null) {
      await prefs.setString(_kOnboardingProfileName, _profileName!);
    }
    await prefs.setString(_kOnboardingProfileMode, _profileMode);
    await prefs.setString(_kOnboardingLanguage, _selectedLanguage);
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kOnboardingPhase,
      _kOnboardingProfileId,
      _kOnboardingProfileName,
      _kOnboardingProfileMode,
      _kOnboardingLanguage,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── Phase Transitions ──────────────────────────────────────────────────────

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _nameError != null) return;

    final repo = ref.read(profileRepositoryProvider);
    final ProfileModel profile;
    try {
      profile = await repo.createProfile(
        accountId: 1,
        displayName: name,
        mode: _profileMode,
      );
    } on DuplicateProfileNameException {
      if (mounted) {
        setState(() {
          _nameError = 'A profile with this name already exists';
        });
      }
      return;
    }

    // Set user mode via profile service
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      final profileService = ref.read(userProfileServiceProvider);
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: name,
        mode: _profileMode == 'child' ? UserMode.child : UserMode.adult,
      );
    }

    _createdProfileId = profile.id;
    _profileName = name;
    ref.read(selectedProfileIdProvider.notifier).select(profile.id);

    setState(() => _phase = _ScreenPhase.languageSelection);
    await _saveState();
  }

  void _onLanguageSelected() {
    setState(() => _phase = _ScreenPhase.calendarPreference);
    _saveState();
  }

  void _onCalendarPreferenceSet(bool useHebrew) {
    ref.read(useHebrewDateProvider.notifier).setUseHebrewDate(useHebrew);
    setState(() => _phase = _ScreenPhase.addTrack);
    _saveState();
  }

  void _onAddTrackComplete(AddTrackResult result) {
    _trackCount++;
    _lastTrackLabel = result.label;
    setState(() => _phase = _ScreenPhase.addAnotherPrompt);
    _saveState();
  }

  void _onAddTrackCancel() {
    // Back from AddTrackFlow Stage 1 → return to language selection
    setState(() => _phase = _ScreenPhase.languageSelection);
  }

  void _onAddAnotherTrack() {
    setState(() => _phase = _ScreenPhase.addTrack);
    _saveState();
  }

  void _onStartLearning() {
    if (_isChildMode) {
      setState(() => _phase = _ScreenPhase.handoff);
    } else {
      _navigateToDashboard();
    }
    _saveState();
  }

  Future<void> _addAnotherLearner() async {
    _nameController.clear();
    _createdProfileId = null;
    _profileName = null;
    _profileMode = 'adult';
    _nameError = null;
    _trackCount = 0;
    _lastTrackLabel = null;
    setState(() => _phase = _ScreenPhase.profileCreation);
    await _saveState();
  }

  Future<void> _navigateToDashboard() async {
    await _clearSavedState();
    // Mark onboarding as permanently complete so it's never shown again.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingComplete, true);
    if (!mounted) return;
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.getProfilesByAccount(1);
    if (!mounted) return;
    if (profiles.length >= 2) {
      unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
    } else {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  // ── Build Methods ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appBarTitle = switch (_phase) {
      _ScreenPhase.profileCreation => 'Add a Learner',
      _ScreenPhase.languageSelection => 'Choose Language',
      _ScreenPhase.calendarPreference => 'Calendar',
      _ScreenPhase.addTrack => 'Set Up a Track',
      _ScreenPhase.addAnotherPrompt => 'Track Ready!',
      _ScreenPhase.handoff => 'Setup Complete!',
      _ScreenPhase.done => 'All Set!',
    };

    // Hide app bar during AddTrackFlow (it has its own progress indicator)
    final showAppBar = _phase != _ScreenPhase.addTrack;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: AppBarTitle(text: appBarTitle)) : null,
      body: SafeArea(
        child: switch (_phase) {
          _ScreenPhase.profileCreation => _buildProfileCreation(theme),
          _ScreenPhase.languageSelection => _buildLanguageSelection(theme),
          _ScreenPhase.calendarPreference => _buildCalendarPreference(theme),
          _ScreenPhase.addTrack => _buildAddTrack(),
          _ScreenPhase.addAnotherPrompt => _buildAddAnotherPrompt(theme),
          _ScreenPhase.handoff => _buildHandoff(theme),
          _ScreenPhase.done => _buildDone(theme),
        },
      ),
    );
  }

  Widget _buildProfileCreation(ThemeData theme) {
    final prompt = _profileMode == 'child'
        ? "What is your child's name?"
        : "What's your name?";

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prompt,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'adult', label: Text('Adult')),
                ButtonSegment(value: 'child', label: Text('Child')),
              ],
              selected: {_profileMode},
              onSelectionChanged: (value) {
                setState(() => _profileMode = value.first);
              },
            ),
            const Spacer(),
            FilledButton(
              onPressed:
                  _nameController.text.trim().isNotEmpty && _nameError == null
                  ? _createProfile
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Choose your preferred language for content',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'You can change this later in Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _supportedLanguages.length,
            itemBuilder: (context, index) {
              final entry = _supportedLanguages.entries.elementAt(index);
              final isSelected = _selectedLanguage == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Card(
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
                    onTap: () => setState(() => _selectedLanguage = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : null,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          else
                            Icon(
                              Icons.circle_outlined,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed: _onLanguageSelected,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarPreference(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Which calendar do you prefer?',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This applies to dates throughout the app. You can change it later in Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => _onCalendarPreferenceSet(true),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Hebrew Calendar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _onCalendarPreferenceSet(false),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Gregorian Calendar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTrack() {
    return AddTrackFlow(
      profileId: _createdProfileId ?? 0,
      isOnboarding: true,
      isChildMode: _isChildMode,
      onComplete: _onAddTrackComplete,
      onCancel: _onAddTrackCancel,
    );
  }

  Widget _buildAddAnotherPrompt(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Your track "${_lastTrackLabel ?? ""}" is ready!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have $_trackCount track${_trackCount == 1 ? '' : 's'} set up.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _onStartLearning,
                child: const Text('Start Learning'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onAddAnotherTrack,
                child: const Text('Add Another Track'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandoff(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "${_profileName ?? 'Your child'}'s learning is all set up",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hand the device to ${_profileName ?? 'your child'} to start learning',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You can set up rewards later in Parent Mode',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _navigateToDashboard,
                child: const Text('Start Learning'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onAddAnotherTrack,
                child: const Text('Add Another Track'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _addAnotherLearner,
                child: const Text('Add Another Learner'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('All set!', style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}
