import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Callback type for when profile creation is complete.
typedef ProfileCreatedCallback =
    void Function({
      required ProfileModel profile,
      required bool isChildMode,
      required bool useHebrewCalendar,
      required bool useHebrewTerms,
      required bool showNikud,
      required TransliterationVariant transliterationVariant,
    });

/// Onboarding phase: gather name, mode, and display preferences, then create
/// the profile row.
class OnboardingProfileCreationStep extends ConsumerStatefulWidget {
  const OnboardingProfileCreationStep({
    super.key,
    required this.onCreated,
    // WS2.skip: optional callback — when provided, a "Skip for now" affordance
    // is shown at the bottom so the user can bypass profile creation entirely
    // and reach the empty-login surface.
    this.onSkipProfileCreation,
  });

  final ProfileCreatedCallback onCreated;

  /// Called when the user taps "Skip for now" at the profile-creation phase.
  /// Null = no skip affordance rendered.
  final VoidCallback? onSkipProfileCreation;

  @override
  ConsumerState<OnboardingProfileCreationStep> createState() =>
      _OnboardingProfileCreationStepState();
}

class _OnboardingProfileCreationStepState
    extends ConsumerState<OnboardingProfileCreationStep> {
  final _nameController = TextEditingController();
  String _profileMode = 'adult';
  bool _useHebrewCalendar = true;
  bool _showNikud = true;
  bool _useHebrewTerms = true;
  final TransliterationVariant _transliterationVariant =
      TransliterationVariant.ashkenazi;
  String? _nameError;
  bool _isCreatingProfile = false;

  bool get _isChildMode => _profileMode == 'child';

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

    // WS9.flows: setUserMode (account-level userMode) removed — mode is stored
    // in learner_profiles.mode and synced via the profile repository, not via
    // a separate Firestore account-doc write.

    // AUD-onboarding-01 (SM-4): repo.createProfile(...) above is a DB write
    // that may still be in flight when the step widget is popped (e.g. the
    // user backs out of onboarding). Touching `ref` unconditionally after
    // that await throws once this State is disposed — bail out first.
    if (!mounted) return;

    ref.read(selectedProfileIdProvider.notifier).select(profile.id);
    await PendingLocalSignupStore.finalizeAfterFirstProfile(ref);

    if (mounted) setState(() => _isCreatingProfile = false);

    widget.onCreated(
      profile: profile,
      isChildMode: _isChildMode,
      useHebrewCalendar: _useHebrewCalendar,
      useHebrewTerms: _useHebrewTerms,
      showNikud: _showNikud,
      transliterationVariant: _transliterationVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const cardRadius = 20.0;
    const prefsBg = AppTheme.brandCreamSoft;

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
            color: selected ? AppTheme.brandBlue : AppTheme.brandOutline,
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
                    color: selected ? Colors.white : AppTheme.brandInk,
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
          color: AppTheme.brandOutline,
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
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(cardRadius),
              elevation: selected ? 0 : 1,
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: () =>
                    setState(() => _profileMode = isChild ? 'child' : 'adult'),
                borderRadius: BorderRadius.circular(cardRadius),
                child: Container(
                  width: double.infinity,
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
                    AppLocalizations.of(context)!.pointSettingsActiveBadge,
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
              AppLocalizations.of(context)!.onboardingNamePrompt,
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
              // Profile names are stored verbatim; soft-keyboard autocorrect
              // was mangling typed names (e.g. "Talmid1" -> "Talmid16").
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: const [TrimLeadingSpaceFormatter()],
              style: const TextStyle(color: AppTheme.brandInk),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.enterNameHint,
                errorText: _nameError,
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
              AppLocalizations.of(context)!.onboardingLearningExperience,
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
                  title: AppLocalizations.of(context)!.childModeCardTitle,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.childModeCardSubtitleFunRewards,
                ),
                const SizedBox(width: 12),
                modeCard(
                  isChild: false,
                  icon: Icons.menu_book_rounded,
                  iconBgMuted: AppTheme.brandOutline,
                  title: AppLocalizations.of(context)!.adultModeCardTitle,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.adultModeCardSubtitleDeepFocused,
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
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.settingsNikud,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  pillPair(
                    leftLabel: AppLocalizations.of(
                      context,
                    )!.settingsNikudWithout,
                    rightLabel: AppLocalizations.of(context)!.settingsNikudWith,
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
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.onboardingCalendarLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  pillPair(
                    leftLabel: AppLocalizations.of(context)!.calendarGregorian,
                    rightLabel: AppLocalizations.of(context)!.calendarHebrew,
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
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context)!.hebrewTermsPreference,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    pillPair(
                      leftLabel: AppLocalizations.of(
                        context,
                      )!.hebrewTermsEnglish,
                      rightLabel: AppLocalizations.of(
                        context,
                      )!.hebrewTermsHebrew,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context)!.createProfile,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
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
              AppLocalizations.of(context)!.onboardingSettingsChangeableLater,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.brandInkMuted,
              ),
            ),
            // WS2.skip: skip affordance — only shown when a callback is wired.
            if (widget.onSkipProfileCreation != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onSkipProfileCreation,
                child: Text(
                  AppLocalizations.of(context)!.actionSkipForNow,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
