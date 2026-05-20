import 'package:shared_preferences/shared_preferences.dart';

// ── SharedPreferences keys for onboarding state persistence ──────────────────

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

/// W6.1/W6.3: persist skip intent for dashboard empty-state CTAs.
const kOnboardingSkipped = 'onboarding_skipped';
const kOnboardingJoinedToTutor = 'onboarding_joined_to_tutor';

// ── OnboardingSnapshot ───────────────────────────────────────────────────────

/// Snapshot of onboarding state as loaded from [SharedPreferences].
class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.phase,
    required this.profileId,
    required this.profileName,
    required this.profileMode,
    required this.useHebrewCalendar,
    required this.useHebrewTerms,
    required this.showNikud,
    required this.transliterationVariant,
  });

  final String? phase;
  final int? profileId;
  final String? profileName;
  final String? profileMode;
  final bool useHebrewCalendar;
  final bool useHebrewTerms;
  final bool showNikud;
  final String? transliterationVariant;
}

// ── OnboardingResumeStore ────────────────────────────────────────────────────

/// Handles save / load / clear of in-progress onboarding state via
/// [SharedPreferences].
///
/// Extracted from [OnboardingScreen] so the persistence concern is separate
/// from the UI orchestration concern.
class OnboardingResumeStore {
  const OnboardingResumeStore();

  /// Load the persisted snapshot. Returns `null` if no saved state exists.
  Future<OnboardingSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kOnboardingPhase);
    if (savedPhase == null) return null;

    return OnboardingSnapshot(
      phase: savedPhase,
      profileId: prefs.getInt(_kOnboardingProfileId),
      profileName: prefs.getString(_kOnboardingProfileName),
      profileMode: prefs.getString(_kOnboardingProfileMode),
      useHebrewCalendar: prefs.getBool(_kOnboardingHebrewCalendar) ?? true,
      useHebrewTerms: prefs.getBool(_kOnboardingHebrewTerms) ?? true,
      showNikud: prefs.getBool(_kOnboardingShowNikud) ?? true,
      transliterationVariant: prefs.getString(
        _kOnboardingTransliterationVariant,
      ),
    );
  }

  /// Persist the current onboarding state so it can be resumed on restart.
  Future<void> save({
    required String phase,
    int? profileId,
    String? profileName,
    required String profileMode,
    required bool useHebrewCalendar,
    required bool useHebrewTerms,
    required bool showNikud,
    required String transliterationVariant,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOnboardingPhase, phase);
    if (profileId != null) {
      await prefs.setInt(_kOnboardingProfileId, profileId);
    }
    if (profileName != null) {
      await prefs.setString(_kOnboardingProfileName, profileName);
    }
    await prefs.setString(_kOnboardingProfileMode, profileMode);
    await prefs.setBool(_kOnboardingHebrewCalendar, useHebrewCalendar);
    await prefs.setBool(_kOnboardingHebrewTerms, useHebrewTerms);
    await prefs.setBool(_kOnboardingShowNikud, showNikud);
    await prefs.setString(
      _kOnboardingTransliterationVariant,
      transliterationVariant,
    );
  }

  /// Clear all onboarding-in-progress keys (does not clear [kOnboardingComplete]).
  Future<void> clear() async {
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

  /// Mark onboarding as permanently complete so it is never shown again.
  Future<void> markComplete({
    bool skipped = false,
    bool joinedToTutor = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingComplete, true);
    if (skipped) {
      await prefs.setBool(kOnboardingSkipped, true);
      await prefs.setBool(kOnboardingJoinedToTutor, joinedToTutor);
    }
  }
}
