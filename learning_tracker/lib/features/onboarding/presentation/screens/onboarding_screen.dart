import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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
  parentPinSetup,
  addTrack,
  addAnotherPrompt,
  permissionPrompt,
  handoff,
  done,
}

/// Sub-steps within [_ScreenPhase.parentPinSetup].
///
/// Replaces the `_isPinConfirmStep` boolean so the two sub-states are named
/// and exhaustively handled.
enum _PinStep {
  /// User is entering the PIN for the first time.
  enterPin,

  /// User is re-entering the PIN to confirm it matches.
  confirmPin,
}

// SharedPreferences keys for onboarding state persistence
const _kOnboardingPhase = 'onboarding_phase';
const _kOnboardingProfileId = 'onboarding_profile_id';
const _kOnboardingProfileName = 'onboarding_profile_name';
const _kOnboardingProfileMode = 'onboarding_profile_mode';
const _kOnboardingHebrewCalendar = 'onboarding_use_hebrew_calendar';
const _kOnboardingHebrewTerms = 'onboarding_use_hebrew_terms';
const _kOnboardingShowNikud = 'onboarding_show_nikud';
const _kOnboardingTransliterationVariant = 'onboarding_transliteration_variant';

/// Persistent flag — once set, onboarding is never shown again on this device.
const kOnboardingComplete = 'onboarding_complete';

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// `true` = Hebrew calendar; `false` = Gregorian (matches UI labels).
  bool _useHebrewCalendar = true;

  /// `true` = render Hebrew text with nikud (vowel marks); `false` = strip.
  bool _showNikud = true;

  bool _useHebrewTerms = true;

  TransliterationVariant _transliterationVariant =
      TransliterationVariant.ashkenazi;
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
  bool _isCreatingProfile = false;

  bool get _isChildMode => _profileMode == 'child';

  @override
  void initState() {
    super.initState();
    _tryResumeFromSavedState();
    _nameController.addListener(_validateProfileName);
    // Epic 20.6: onboarding is only reachable after signup. If the
    // user somehow lands here without a live AuthState session
    // (signedOut / initializing fallthrough), bounce them back to
    // the sign-in screen so they can sign up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (!authState.isSignedIn) {
        unawaited(context.router.replaceAll([const SignInRoute()]));
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

  // ── State Persistence ──────────────────────────────────────────────────────

  Future<void> _tryResumeFromSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kOnboardingPhase);
    if (savedPhase == null) return;

    final profileId = prefs.getInt(_kOnboardingProfileId);
    final profileName = prefs.getString(_kOnboardingProfileName);
    final profileMode = prefs.getString(_kOnboardingProfileMode);

    if (profileId != null) _createdProfileId = profileId;
    if (profileName != null) _profileName = profileName;
    if (profileMode != null) _profileMode = profileMode;
    _useHebrewCalendar = prefs.getBool(_kOnboardingHebrewCalendar) ?? true;
    _useHebrewTerms = prefs.getBool(_kOnboardingHebrewTerms) ?? true;
    _showNikud = prefs.getBool(_kOnboardingShowNikud) ?? true;
    final savedVariant = prefs.getString(_kOnboardingTransliterationVariant);
    if (savedVariant == 'sephardi') {
      _transliterationVariant = TransliterationVariant.sephardi;
    }

    // If the user already advanced this session (e.g., tapped Continue
    // quickly), don't let a delayed restore overwrite the newer phase.
    if (!mounted || _phase != _ScreenPhase.profileCreation) return;

    // Legacy: older builds created the profile row before the calendar step.
    if (profileId != null && savedPhase == 'calendarPreference') {
      setState(() {
        _phase = _ScreenPhase.addTrack;
      });
      return;
    }

    final phase = _ScreenPhase.values.where((p) => p.name == savedPhase);
    if (phase.isNotEmpty) {
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
    await prefs.setBool(_kOnboardingHebrewCalendar, _useHebrewCalendar);
    await prefs.setBool(_kOnboardingHebrewTerms, _useHebrewTerms);
    await prefs.setBool(_kOnboardingShowNikud, _showNikud);
    await prefs.setString(
      _kOnboardingTransliterationVariant,
      _transliterationVariant.name,
    );
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kOnboardingPhase,
      _kOnboardingProfileId,
      _kOnboardingProfileName,
      _kOnboardingProfileMode,
      _kOnboardingHebrewCalendar,
      _kOnboardingHebrewTerms,
      _kOnboardingShowNikud,
      _kOnboardingTransliterationVariant,
    ]) {
      await prefs.remove(key);
    }
  }

  // ── Phase Transitions ──────────────────────────────────────────────────────

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _nameError != null || _isCreatingProfile) return;
    setState(() => _isCreatingProfile = true);

    // App locale is auto-detected from the device locale by MaterialApp
    // (DNI-341). No user-driven setLocale call here.
    await ref.read(useHebrewDateProvider.notifier).set(_useHebrewCalendar);
    await ref.read(showNikudProvider.notifier).set(_showNikud);
    await ref.read(useHebrewTermsProvider.notifier).set(_useHebrewTerms);
    await ref
        .read(currentTransliterationVariantProvider.notifier)
        .set(_transliterationVariant);

    final repo = ref.read(profileRepositoryProvider);
    final accountId = ref.read(currentAccountIdProvider);
    final ProfileModel profile;
    try {
      profile = await repo.createProfile(
        accountId: accountId,
        displayName: name,
        mode: _profileMode,
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
    // Local-born accounts often still have a stale Firebase session on device;
    // awaiting Firestore here blocks offline-first profile creation indefinitely.
    final authState = ref.read(authStateProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    if (authState.isCloudBorn && user != null) {
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

    await PendingLocalSignupStore.finalizeAfterFirstProfile(ref);

    setState(
      () => _phase = _isChildMode
          ? _ScreenPhase.parentPinSetup
          : _ScreenPhase.addTrack,
    );
    await _saveState();
    if (mounted) {
      setState(() => _isCreatingProfile = false);
    }
  }

  // Parent PIN setup state (child mode only).
  String? _firstPin;
  String? _pinError;
  _PinStep _pinStep = _PinStep.enterPin;

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _pinStep = _PinStep.confirmPin;
      _pinError = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _pinError = 'PINs do not match';
        _pinStep = _PinStep.enterPin;
        _firstPin = null;
      });
      return;
    }
    final profileId = _createdProfileId;
    if (profileId == null) return;

    try {
      await ref.read(pinServiceProvider).setProfilePin(profileId, pin);
    } on ArgumentError catch (e) {
      setState(() {
        _pinError = e.message as String?;
        _pinStep = _PinStep.enterPin;
        _firstPin = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _firstPin = null;
      _pinStep = _PinStep.enterPin;
      _pinError = null;
      _phase = _ScreenPhase.addTrack;
    });
    await _saveState();
  }

  void _onAddTrackComplete(AddTrackResult result) {
    _trackCount++;
    _lastTrackLabel = result.label;
    setState(() => _phase = _ScreenPhase.addAnotherPrompt);
    _saveState();
  }

  void _onAddTrackCancel() {
    // If the learner row is not committed yet, return to the combined form.
    if (_createdProfileId == null) {
      setState(() => _phase = _ScreenPhase.profileCreation);
      return;
    }
    // Profile + prefs already saved — cannot re-use the create form.
    if (_isChildMode) {
      setState(() => _phase = _ScreenPhase.handoff);
    } else {
      unawaited(_navigateToDashboard());
    }
  }

  void _onAddAnotherTrack() {
    setState(() => _phase = _ScreenPhase.addTrack);
    _saveState();
  }

  void _onStartLearning() {
    // Both adult and child modes go through the permission prompt — device-level
    // permissions (notifications, location) apply to the whole app, not a
    // profile. After permissions the child path continues to the handoff screen.
    setState(() => _phase = _ScreenPhase.permissionPrompt);
    _saveState();
  }

  Future<void> _addAnotherLearner() async {
    _nameController.clear();
    _createdProfileId = null;
    _profileName = null;
    _profileMode = 'adult';
    _useHebrewCalendar = true;
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
    final profiles = await repo.getProfilesByAccount(
      ref.read(currentAccountIdProvider),
    );
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

    final isCombinedProfilePhase = _phase == _ScreenPhase.profileCreation;

    final appBarTitle = switch (_phase) {
      _ScreenPhase.profileCreation => const SizedBox.shrink(),
      _ScreenPhase.parentPinSetup => const AppBarTitle(text: 'Set Parent PIN'),
      _ScreenPhase.addTrack => const AppBarTitle(text: 'Set Up a Track'),
      _ScreenPhase.addAnotherPrompt => const AppBarTitle(text: 'Track Ready!'),
      _ScreenPhase.permissionPrompt => const AppBarTitle(text: 'Almost Done!'),
      _ScreenPhase.handoff => const AppBarTitle(text: 'Setup Complete!'),
      _ScreenPhase.done => const AppBarTitle(text: 'All Set!'),
    };

    // Hide app bar during AddTrackFlow (it has its own progress indicator).
    // Combined profile step has no app bar (back lives in the scroll content).
    // Permission prompt pushes its own full-screen route, so we suppress the
    // outer app bar for the single placeholder frame before it appears.
    final showAppBar =
        _phase != _ScreenPhase.addTrack &&
        _phase != _ScreenPhase.permissionPrompt &&
        !isCombinedProfilePhase;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: appBarTitle) : null,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.2),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          child: switch (_phase) {
            _ScreenPhase.profileCreation => _buildProfileCreation(theme),
            _ScreenPhase.parentPinSetup => _buildParentPinSetup(theme),
            _ScreenPhase.addTrack => _buildAddTrack(),
            _ScreenPhase.addAnotherPrompt => _buildAddAnotherPrompt(theme),
            _ScreenPhase.permissionPrompt => _buildPermissionPrompt(theme),
            _ScreenPhase.handoff => _buildHandoff(theme),
            _ScreenPhase.done => _buildDone(theme),
          },
        ),
      ),
    );
  }

  Widget _buildProfileCreation(ThemeData theme) {
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
      final selected = _profileMode == (isChild ? 'child' : 'adult');
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
                onTap: () =>
                    setState(() => _profileMode = isChild ? 'child' : 'adult'),
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
              inputFormatters: const [TrimLeadingSpaceFormatter()],
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
                    leftSelected: !_showNikud,
                    onLeft: () => setState(() => _showNikud = false),
                    onRight: () => setState(() => _showNikud = true),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 22,
                        color: AppTheme.brandInk,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Calendar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  pillPair(
                    leftLabel: 'English',
                    rightLabel: 'Hebrew',
                    leftSelected: !_useHebrewCalendar,
                    onLeft: () => setState(() => _useHebrewCalendar = false),
                    onRight: () => setState(() => _useHebrewCalendar = true),
                  ),
                  if (Localizations.localeOf(context).languageCode != 'he') ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.translate_rounded,
                          size: 22,
                          color: AppTheme.brandInk,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hebrew Terms',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    pillPair(
                      leftLabel: 'English',
                      rightLabel: 'Hebrew',
                      leftSelected: !_useHebrewTerms,
                      onLeft: () => setState(() => _useHebrewTerms = false),
                      onRight: () => setState(() => _useHebrewTerms = true),
                    ),
                  ],
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

  Widget _buildParentPinSetup(ThemeData theme) {
    final childName = _profileName ?? 'your child';
    final subtitle = switch (_pinStep) {
      _PinStep.confirmPin => 'Re-enter the PIN to confirm',
      _PinStep.enterPin =>
        'Set a 4-digit PIN to access parent controls for $childName. '
            'The PIN is stored only on this device.',
    };

    return SafeArea(
      top: false,
      // Scrollable so the soft keyboard squeezing the viewport scrolls the
      // card instead of overflowing it (was a 10px bottom overflow). The
      // Column is mainAxisSize.min so it only claims the height it needs.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  title: switch (_pinStep) {
                    _PinStep.confirmPin => 'Confirm PIN',
                    _PinStep.enterPin => 'Enter New PIN',
                  },
                  errorMessage: _pinError,
                  onPinComplete: switch (_pinStep) {
                    _PinStep.confirmPin => _onConfirmPinEntered,
                    _PinStep.enterPin => _onFirstPinEntered,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTrack() {
    return AddTrackFlow(
      profileId: _createdProfileId ?? 0,
      isOnboarding: true,
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
                child: Text(AppLocalizations.of(context)!.startLearning),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onAddAnotherTrack,
                child: Text(AppLocalizations.of(context)!.addAnotherTrack),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionPrompt(ThemeData theme) {
    // Push the standalone PermissionPromptScreen; on pop continue to the
    // correct destination: handoff (child) or dashboard (adult).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.pushRoute(PermissionPromptRoute(isOnboarding: true));
      if (!mounted) return;
      if (_isChildMode) {
        setState(() => _phase = _ScreenPhase.handoff);
        await _saveState();
      } else {
        await _navigateToDashboard();
      }
    });
    // Placeholder shown for the single frame before the route is pushed.
    return const SizedBox.shrink();
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
                child: Text(AppLocalizations.of(context)!.startLearning),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _onAddAnotherTrack,
                child: Text(AppLocalizations.of(context)!.addAnotherTrack),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _addAnotherLearner,
                child: Text(AppLocalizations.of(context)!.addAnotherLearner),
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
          Text(
            AppLocalizations.of(context)!.allSet,
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
