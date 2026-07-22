import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Brightness-aware semantic colour tokens for the whole app.
///
/// Every token below resolves to a LIGHT or DARK value from the single
/// [brightness] field, so a widget can never render a light-only colour on a
/// dark surface. This replaced the previous `AppColors` class, which held 244
/// light-only `static const Color`s: under `ThemeMode.system` those painted
/// dark ink on dark cards at ratios as low as 1.02:1 (invisible text).
///
/// Access it from a widget via the [BuildContext] extension:
///
/// ```dart
/// Container(color: context.colors.brandCreamCard)
/// ```
///
/// Contract for adding a token:
///   * give it a SEMANTIC name (what it means, not where it is used);
///   * supply BOTH a light and a dark value on the same line;
///   * foreground tokens must clear 4.5:1 against their paired surface in
///     BOTH modes (`test/theme/palette_contrast_test.dart` enforces this).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.brightness});

  /// The brightness this palette resolves against.
  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;

  /// The light-mode palette.
  static const AppPalette light = AppPalette(brightness: Brightness.light);

  /// The dark-mode palette.
  static const AppPalette dark = AppPalette(brightness: Brightness.dark);

  /// Resolves the palette registered on the ambient [Theme].
  ///
  /// Falls back to the light palette if no [AppPalette] is registered, so a
  /// widget pumped in a bare `MaterialApp` in a test still renders sensibly.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? AppPalette.light;

  @override
  AppPalette copyWith({Brightness? brightness}) =>
      AppPalette(brightness: brightness ?? this.brightness);

  /// Brightness is a discrete choice, so the palette switches at the midpoint
  /// of a theme transition rather than interpolating through invalid blends.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPalette && other.brightness == brightness);

  @override
  int get hashCode => brightness.hashCode;

  // ---------------------------------------------------------------------------
  // Core brand, surface, ink and status roles
  // ---------------------------------------------------------------------------

  /// Primary royal blue.
  Color get brandBlue =>
      _dark ? const Color(0xFF7CA0FF) : const Color(0xFF1442B8);

  /// Lifted primary (hover/active, chart fills).
  Color get brandBlueBright =>
      _dark ? const Color(0xFFA3BEFF) : const Color(0xFF2B5FD9);

  /// Deep primary (headings on tint, pressed).
  ///
  /// "Deep" is a CONTRAST role, not a fixed hue: on a dark surface the
  /// legible "deep" tone is a LIGHT blue, so this lightens rather than
  /// darkens in dark mode.
  Color get brandBlueDeep =>
      _dark ? const Color(0xFFB9C9FF) : const Color(0xFF0E3392);

  /// Primary tint container.
  Color get brandBlueSoft =>
      _dark ? const Color(0xFF16233F) : const Color(0xFFE4EBFA);

  /// Warm accent — streaks, highlights, badges.
  Color get brandCoral =>
      _dark ? const Color(0xFFFF8A5C) : const Color(0xFFE05A30);

  /// Warm accent tint container.
  Color get brandCoralSoft =>
      _dark ? const Color(0xFF2E1C14) : const Color(0xFFFDE9E2);

  /// Warm accent text tone (AA on its tint).
  Color get brandCoralDeep =>
      _dark ? const Color(0xFFFFB294) : const Color(0xFFB03F1D);

  /// Warning / caution.
  Color get brandWarning =>
      _dark ? const Color(0xFFE0A54A) : const Color(0xFFC77A12);

  /// Warning tint container.
  Color get brandWarningSoft =>
      _dark ? const Color(0xFF2E220E) : const Color(0xFFFBF0DC);

  /// Warning text tone.
  Color get brandWarningDeep =>
      _dark ? const Color(0xFFF0C883) : const Color(0xFF8A5306);

  /// Success / progress (olive).
  Color get brandGold =>
      _dark ? const Color(0xFF8FBF5F) : const Color(0xFF4F7A28);

  /// Success tint container.
  Color get brandGoldSoft =>
      _dark ? const Color(0xFF1B2A12) : const Color(0xFFE3EDD3);

  /// Success text tone.
  Color get brandGoldDeep =>
      _dark ? const Color(0xFFB4D98C) : const Color(0xFF3A5C1B);

  /// App canvas / scaffold.
  Color get brandCream =>
      _dark ? const Color(0xFF0B0F1A) : const Color(0xFFF7F8FB);

  /// Card & sheet surface.
  Color get brandCreamCard =>
      _dark ? const Color(0xFF151A26) : const Color(0xFFFFFFFF);

  /// Recessed / secondary surface.
  Color get brandCreamSoft =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFEFF2F7);

  /// Card borders & dividers (VISIBLE in both modes).
  Color get brandOutline =>
      _dark ? const Color(0xFF263041) : const Color(0xFFD4DCE8);

  /// Stronger border / emphasis rule.
  Color get brandOutlineMuted =>
      _dark ? const Color(0xFF36425A) : const Color(0xFFC7D0DE);

  /// Primary text & icons.
  Color get brandInk =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF101828);

  /// Body text.
  Color get brandInk2 =>
      _dark ? const Color(0xFFC3CBD8) : const Color(0xFF2B3444);

  /// Secondary text (AA on surface).
  Color get brandInkMuted =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF5A6474);

  /// Tertiary text / hints (AA on surface).
  Color get brandInkSoft =>
      _dark ? const Color(0xFF828D9E) : const Color(0xFF6A7484);

  /// Error / destructive.
  Color get brandError =>
      _dark ? const Color(0xFFF0857B) : const Color(0xFFC0362C);

  /// Error tint container.
  Color get brandErrorSoft =>
      _dark ? const Color(0xFF2E1512) : const Color(0xFFFBE9E7);

  // ---------------------------------------------------------------------------
  // Curriculum identity colours (domain identity, lifted for dark surfaces)
  // ---------------------------------------------------------------------------

  Color get curriculumMishna =>
      _dark ? const Color(0xFF62D186) : const Color(0xFF277B3C);

  Color get curriculumBavli =>
      _dark ? const Color(0xFF4FC4A8) : const Color(0xFF1B6B5A);

  Color get curriculumYerushalmi =>
      _dark ? const Color(0xFF7FA8FF) : const Color(0xFF1A57C2);

  Color get curriculumMishnaBerurah =>
      _dark ? const Color(0xFF8FBF5F) : const Color(0xFF4F7A28);

  Color get curriculumChumash =>
      _dark ? const Color(0xFFD9A54B) : const Color(0xFF8A5E1D);

  Color get curriculumNach =>
      _dark ? const Color(0xFF3FD3CE) : const Color(0xFF0B7D79);

  Color get curriculumMussar =>
      _dark ? const Color(0xFFAF8CFA) : const Color(0xFF6D28D9);

  // ---------------------------------------------------------------------------
  // Feature tokens (migrated from AppColors; dark values derived and
  // contrast-verified against the dark surface ramp)
  // ---------------------------------------------------------------------------

  /// Generic error/danger red used in UI badges, streak-break indicators,
  /// etc.
  Color get statusError =>
      _dark ? const Color(0xFFDE8686) : const Color(0xFFC92A2A);

  /// Lighter error tint (badge backgrounds, alert backgrounds).
  Color get statusErrorSoft =>
      _dark ? const Color(0xFF331318) : const Color(0xFFFDE7EA);

  /// Slightly brighter danger red for notifications / overdue indicators.
  Color get statusDanger =>
      _dark ? const Color(0xFFE97B7B) : const Color(0xFFF26666);

  /// Amber / warning amber (overdue-light, caution banners).
  Color get statusWarning =>
      _dark ? const Color(0xFFE6B96A) : const Color(0xFFE9A42A);

  /// Warning background tint.
  Color get statusWarningSoft =>
      _dark ? const Color(0xFF332B13) : const Color(0xFFFFF2CF);

  /// Success green for completion confirmations.
  Color get statusSuccess =>
      _dark ? const Color(0xFF72DE9A) : const Color(0xFF22C55E);

  /// Muted success green (streak active, in-progress items).
  Color get statusSuccessMuted =>
      _dark ? const Color(0xFF72DEA4) : const Color(0xFF3BDD87);

  /// Deep success green (siyum / full-track complete).
  Color get statusSuccessDeep =>
      _dark ? const Color(0xFF93D196) : const Color(0xFF2E7D32);

  /// Very light blue-grey surface — scaffold backgrounds, content screens.
  Color get surfaceF5 =>
      _dark ? const Color(0xFF131C33) : const Color(0xFFF5F7FC);

  /// Light neutral surface for section backgrounds.
  Color get surfaceF3 =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFF3F4F8);

  /// Slightly warmer light neutral (step card backgrounds).
  Color get surfaceF4 =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFF4F5F8);

  /// Slightly different warm-neutral variant.
  Color get surfaceF4b =>
      _dark ? const Color(0xFF131C33) : const Color(0xFFF4F6FB);

  /// Common widget tray / card surface — border colour and inactive
  /// backgrounds.
  Color get surfaceE9 =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE9ECF2);

  /// Soft blue-tinted neutral (card tint, progress containers).
  Color get surfaceBlueNeutral =>
      _dark ? const Color(0xFF161D30) : const Color(0xFFF0F2F8);

  /// Light lavender-blue tint (selected chip bg, blue-themed items).
  Color get surfaceBlueLight =>
      _dark ? const Color(0xFF131833) : const Color(0xFFE5E9FF);

  /// Light grey-blue (divider lines, outline borders).
  Color get surfaceGreyBlue =>
      _dark ? const Color(0xFF181E2F) : const Color(0xFFE2E6F0);

  /// Deep brand-navy (gradient bottom, heavy chip backgrounds).
  Color get blueNavy =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF03174C);

  /// Dark navy variant used in deep screen gradients.
  Color get blueDeepNavy =>
      _dark ? const Color(0xFFAFC0E8) : const Color(0xFF0A2056);

  /// Bright medium blue (selected-tab highlight, step indicator active).
  Color get blueMedium =>
      _dark ? const Color(0xFFAFBEE8) : const Color(0xFF1C47C4);

  /// Slightly lighter mid-blue (button tints, tile borders).
  Color get blueLight =>
      _dark ? const Color(0xFFAFBDE8) : const Color(0xFF1639A8);

  /// Another mid-blue shade used in tracks-setup components.
  Color get blueMid =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF123DAE);

  /// Trophy gold (streak flame icon, milestone badge fill).
  Color get goldTrophy =>
      _dark ? const Color(0xFF332A13) : const Color(0xFFFFC94A);

  /// Warm amber (point bubbles, reward-card header).
  Color get goldAmber =>
      _dark ? const Color(0xFFE6B96A) : const Color(0xFFE9A42A);

  /// Dark amber / honey (text on gold backgrounds).
  Color get goldDark =>
      _dark ? const Color(0xFFE8D2AF) : const Color(0xFF7D5411);

  /// Warm peach tint (reward card body background).
  Color get peachTint =>
      _dark ? const Color(0xFF332513) : const Color(0xFFF9E4C8);

  /// Medium amber-peach (icon backgrounds on reward cards).
  Color get peachMid =>
      _dark ? const Color(0xFF332613) : const Color(0xFFF3D4A5);

  /// Peach amber-dark (reward card text).
  Color get peachDark =>
      _dark ? const Color(0xFFE1D2B6) : const Color(0xFF594624);

  /// Warning-tone soft yellow (overdue banners, reminder badges).
  Color get warnYellow =>
      _dark ? const Color(0xFF332B13) : const Color(0xFFFFF2CF);

  /// Chart series colour — primary blue.
  Color get chartBlue =>
      _dark ? const Color(0xFF699DE6) : const Color(0xFF4D96FF);

  /// Chart series colour — teal-cyan.
  Color get chartTeal =>
      _dark ? const Color(0xFF7BDFE9) : const Color(0xFF0097A7);

  /// Chart series colour — green.
  Color get chartGreen =>
      _dark ? const Color(0xFF83CC8C) : const Color(0xFF6BCB77);

  /// Chart series colour — amber.
  Color get chartAmber =>
      _dark ? const Color(0xFF332913) : const Color(0xFFF8C146);

  /// Chart series colour — red.
  Color get chartRed =>
      _dark ? const Color(0xFFD58F99) : const Color(0xFFB43A4A);

  /// Chart bar background (empty bar).
  Color get chartBarBg =>
      _dark ? const Color(0xFF2A3346) : const Color(0xFF404060);

  /// Chart bar fill (inactive / muted).
  Color get chartBarFillMuted =>
      _dark ? const Color(0xFF36425A) : const Color(0xFF9E9E9E);

  /// Streak active day fill (bright green).
  Color get streakActive =>
      _dark ? const Color(0xFF4ADE80) : const Color(0xFF69F0AE);

  /// Streak empty / rest day (muted blue-grey).
  Color get streakEmpty =>
      _dark ? const Color(0xFF4A5568) : const Color(0xFF90A4AE);

  /// Very dark ink (near-black) for display headings in dark containers.
  Color get inkDeepDark =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF1A1A1A);

  /// Standard dark slate used for body text on white cards.
  Color get inkSlate =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF4A5568);

  /// Mid-grey muted text (sub-labels, placeholders).
  Color get inkMidGrey =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF8E97A6);

  /// Light blue-grey icon colour.
  Color get iconBlueGrey =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF78909C);

  /// Deep purple accent (mussar curriculum, some achievement icons).
  Color get accentPurpleDeep =>
      _dark ? const Color(0xFFC2B0E7) : const Color(0xFF4A2A8A);

  /// Teal-green accent (Nach / Yerushalmi identity icon).
  Color get accentTealGreen =>
      _dark ? const Color(0xFF88DCD3) : const Color(0xFF1D7D73);

  /// Light teal surface for content-type chips.
  Color get accentTealSoft =>
      _dark ? const Color(0xFF132833) : const Color(0xFFE0F4FF);

  /// Coral/salmon for overdue / missed tasks.
  Color get accentCoral =>
      _dark ? const Color(0xFFE66969) : const Color(0xFFF86B6B);

  /// Burnt-orange accent (warning chips, deadline chip).
  Color get accentBurntOrange =>
      _dark ? const Color(0xFFE9A27B) : const Color(0xFFC24400);

  /// Dark scrim overlay (0x40 ≈ 25 % opacity black).
  Color get scrimDark =>
      _dark ? const Color(0x99000000) : const Color(0x40000000);

  /// Light scrim overlay.
  Color get scrimLight =>
      _dark ? const Color(0x33FFFFFF) : const Color(0x33FFFFFF);

  /// Success-state card background (accept/rescind confirmation cards, tutor
  /// PIN reset success card).
  Color get statusSuccessSoftBg =>
      _dark ? const Color(0xFF173017) : const Color(0xFFEAF5EA);

  /// Success-state card text/icon colour, paired with [statusSuccessSoftBg].
  Color get statusSuccessSoftText =>
      _dark ? const Color(0xFF9ACA9A) : const Color(0xFF3A7C3A);

  /// Warning-state text/icon colour, paired with the existing
  /// [statusWarningSoft] background (decline/PIN-reset warning cards).
  Color get statusWarningSoftText =>
      _dark ? const Color(0xFFE9C77B) : const Color(0xFF916400);

  /// Error-state card background (decline/accept error steps).
  Color get statusErrorCardBg =>
      _dark ? const Color(0xFF331318) : const Color(0xFFFFEBEE);

  /// Error-state card text/icon colour, paired with [statusErrorCardBg].
  Color get statusErrorCardText =>
      _dark ? const Color(0xFFE6807E) : const Color(0xFFD51F1B);

  /// "Active" status badge colour (active tutor grant / accepted invite).
  Color get statusActiveBadge =>
      _dark ? const Color(0xFF96CE99) : const Color(0xFF43A047);

  /// "Pending" status badge colour (pending tutor grant / invite).
  Color get statusPendingBadge =>
      _dark ? const Color(0xFFE6A969) : const Color(0xFFF57C00);

  /// Confirmation-snackbar success green (invite sent, etc.).
  Color get statusSuccessSnackbar =>
      _dark ? const Color(0xFF95CF97) : const Color(0xFF388E3C);

  /// Lavender PIN-badge circle background (Tutor PIN gate/setup/reset icon).
  Color get tutorPinBadgeBg =>
      _dark ? const Color(0xFF1B1333) : const Color(0xFFE8E0FF);

  /// Deep-purple icon colour, paired with [tutorPinBadgeBg].
  Color get tutorPinBadgeIcon =>
      _dark ? const Color(0xFFC9B5E2) : const Color(0xFF6B3FA0);

  /// Neutral border/fill for a disabled PIN keypad key.
  Color get tutorPinKeyDisabled =>
      _dark ? const Color(0xFF3A4459) : const Color(0xFFC9D0DA);

  /// Audit-log action category — config change.
  Color get auditActionConfig =>
      _dark ? const Color(0xFF7DB5E7) : const Color(0xFF1E88E5);

  /// Audit-log action category — bulk prior-completion mark.
  Color get auditActionBulkPrior =>
      _dark ? const Color(0xFF96CE99) : const Color(0xFF43A047);

  /// Audit-log action category — completion reset.
  Color get auditActionReset =>
      _dark ? const Color(0xFFE6A969) : const Color(0xFFF57C00);

  /// Audit-log action category — bookmark advanced.
  Color get auditActionBookmark =>
      _dark ? const Color(0xFFDCAFE8) : const Color(0xFF8E24AA);

  /// Audit-log action category — profile edited.
  Color get auditActionProfileEdited =>
      _dark ? const Color(0xFF7BE9DE) : const Color(0xFF00897B);

  /// Audit-log action category — goal changed.
  Color get auditActionGoalChanged =>
      _dark ? const Color(0xFFB2B9E5) : const Color(0xFF3949AB);

  /// Audit-log action category — stage changed.
  Color get auditActionStageChanged =>
      _dark ? const Color(0xFF7BDFE9) : const Color(0xFF0097A7);

  /// Audit-log action category — reward changed.
  Color get auditActionRewardChanged =>
      _dark ? const Color(0xFFE6B869) : const Color(0xFFFFA000);

  /// Audit-log action category — study-day changed.
  Color get auditActionStudyDayChanged =>
      _dark ? const Color(0xFFE9957B) : const Color(0xFFF4511E);

  /// Tutor-mode context banner background (W6.15) — a warm amber that
  /// contrasts with the app's primary blue to signal "you are in a different
  /// access context".
  Color get tutorModeAccent =>
      _dark ? const Color(0xFFE9B67B) : const Color(0xFFD97706);

  /// Child-view context banner background (WS4.banner) — a teal/emerald green
  /// distinct from both the tutor amber and the primary blue, signalling "you
  /// are inside a child's profile, not your own".
  Color get childViewAccent =>
      _dark ? const Color(0xFF7BE9CA) : const Color(0xFF047857);

  /// Shared opaque pale-blue background for the persistent profile-switcher
  /// bar. Referenced identically from app_shell.dart's ProfileSwitcherBar and
  /// persistent_switcher_scaffold.dart's status-bar inset wrapper so a future
  /// contrast fix only has one definition to update (see app_shell.dart's
  /// "Bug 7" / "Bug 7 (re-fix)" history — AUD-app-03).
  Color get switcherBarBackground =>
      _dark ? const Color(0xFF131A33) : const Color(0xFFF1F3FA);

  /// Border colour paired with [switcherBarBackground].
  Color get switcherBarBorder =>
      _dark ? const Color(0xFF131C33) : const Color(0xFFD7DEF0);

  /// Bottom-nav selected item background / active tab fill.
  Color get navSelectedBlue =>
      _dark ? const Color(0xFFAFC2E8) : const Color(0xFF0038A8);

  /// Bottom-nav bar drop shadow — [navSelectedBlue] at ~8% alpha.
  Color get navBarShadow =>
      _dark ? const Color(0x1C000000) : const Color(0x140038A8);

  /// Selected nav-item drop shadow — [navSelectedBlue] at 20% alpha.
  Color get navItemSelectedShadow =>
      _dark ? const Color(0x47000000) : const Color(0x330038A8);

  /// Unselected bottom-nav icon/label colour (slate grey).
  Color get navUnselectedText =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF708090);

  /// Deep navy used for the intro carousel's hero card fill, chip text, and
  /// accent text (was duplicated as `_kNavy` in 5 files).
  Color get introNavy =>
      _dark ? const Color(0xFFAFBBE8) : const Color(0xFF1A36A5);

  /// Soft peach used for the Mishna/Rewards illustration accent chips.
  Color get introPeach =>
      _dark ? const Color(0xFF331C13) : const Color(0xFFFFD8C8);

  /// Pale blue pill background for the Mishna "review" chip.
  Color get introPillBlue =>
      _dark ? const Color(0xFF131E33) : const Color(0xFFC8D8F8);

  /// Unfilled track colour for the intro progress bars.
  Color get introProgressTrackBg =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE2E5EB);

  /// Filled/active colour for the intro progress bars (Mishna page bar and
  /// the Rewards page's scholar-level example bar).
  Color get introProgressFillGreen =>
      _dark ? const Color(0xFF70DFB5) : const Color(0xFF1DB97D);

  /// Border colour for the Rewards page's "Mystery Prizes" feature card.
  Color get introMysteryBorder =>
      _dark ? const Color(0xFFCCB384) : const Color(0xFFC9A86A);

  /// Circle background behind the Rewards page's "Badge Collection" icon and
  /// the child-mode tag icon.
  Color get introBadgeBg =>
      _dark ? const Color(0xFF131933) : const Color(0xFFE8ECFF);

  /// Circle background behind the Rewards page's "Mystery Prizes" icon.
  Color get introMysteryBg =>
      _dark ? const Color(0xFF332713) : const Color(0xFFFFF3E0);

  /// Text colour on the "Mystery Prizes" feature card.
  Color get introMysteryText =>
      _dark ? const Color(0xFFDFD1B8) : const Color(0xFF5C4A2A);

  /// Icon colour on the "Mystery Prizes" feature card.
  Color get introMysteryIcon =>
      _dark ? const Color(0xFFE8D2AF) : const Color(0xFF6B4E1E);

  /// Drop-shadow colour for the Rewards page's streak badge.
  Color get introCardShadow =>
      _dark ? const Color(0x40000000) : const Color(0x2E000000);

  /// Unfilled track colour for the Rewards page's scholar-level example bar.
  Color get introScholarTrackBg =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE8EAEF);

  /// Inactive-dot colour for the intro page indicator.
  Color get introIndicatorInactive =>
      _dark ? const Color(0xFF263041) : const Color(0xFFDCE0EA);

  /// Third "window dot" accent (sky blue) in the daily-plan illustration's
  /// mock browser-chrome header.
  Color get introWindowDotBlue =>
      _dark ? const Color(0xFF6CC0E4) : const Color(0xFF5BC0EB);

  /// Pill-shaped row background for the daily-plan illustration's checked and
  /// empty task rows.
  Color get introDailyRowPillBg =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFF0F1F4);

  /// Filled track colour for the daily-plan illustration's checked-row
  /// progress bar and the first "empty" row variant.
  Color get introDailyRowTrackFilled =>
      _dark ? const Color(0xFF263041) : const Color(0xFFDCDFE5);

  /// Border colour for the daily-plan illustration's unchecked checkbox
  /// circle.
  Color get introDailyCheckboxBorder =>
      _dark ? const Color(0xFF1E2228) : const Color(0xFFC9CED6);

  /// Unfilled track colour for the daily-plan illustration's second "empty"
  /// row variant.
  Color get introDailyRowTrackEmpty =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE5E7EC);

  /// "Daily Reminder" row icon tint (blue).
  Color get notifReminderIconTint =>
      _dark ? const Color(0xFFAFBDE8) : const Color(0xFF2A4BB3);

  /// "Daily Reminder" row icon background, paired with
  /// [notifReminderIconTint].
  Color get notifReminderIconBg =>
      _dark ? const Color(0xFF131733) : const Color(0xFFE8EBFF);

  /// "Streak Alert" row icon tint (coral).
  Color get notifStreakIconTint =>
      _dark ? const Color(0xFFE18389) : const Color(0xFFD32430);

  /// "Streak Alert" row icon background, paired with [notifStreakIconTint].
  Color get notifStreakIconBg =>
      _dark ? const Color(0xFF331319) : const Color(0xFFFDECEF);

  /// "Reward Milestones" row icon tint (amber).
  Color get notifRewardIconTint =>
      _dark ? const Color(0xFFDBBA89) : const Color(0xFF936623);

  /// "Reward Milestones" row icon background, paired with
  /// [notifRewardIconTint].
  Color get notifRewardIconBg =>
      _dark ? const Color(0xFF332813) : const Color(0xFFFDF2DE);

  /// Settings-group card drop shadow (translucent navy, ~7% alpha).
  Color get notifCardShadow =>
      _dark ? const Color(0x19000000) : const Color(0x12061D56);

  /// Primary row-title text colour (near-black).
  Color get notifTitleText =>
      _dark ? const Color(0xFFB9C2DE) : const Color(0xFF151B2D);

  /// Secondary/subtitle text colour — shared by the settings-row subtitles
  /// and the device-level toggle's status subtitle.
  Color get notifSubtitleText =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF7A8293);

  /// Enabled time-row text colour (reminder/streak time-picker rows).
  Color get notifTimeTextEnabled =>
      _dark ? const Color(0xFFB6C0E1) : const Color(0xFF1A2340);

  /// Disabled time-row text colour.
  Color get notifTimeTextDisabled =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF9CA3B4);

  /// "HOT STREAK" top-badge background.
  Color get notifHotStreakBadge =>
      _dark ? const Color(0xFFE66975) : const Color(0xFFFF6A78);

  /// Device-level OS toggle active track colour.
  Color get notifDeviceToggleActiveTrack =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF123CA5);

  /// Device-level OS toggle inactive track colour.
  Color get notifDeviceToggleInactiveTrack =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE0E4ED);

  Color get gamifChildRewardsCardBlueTop =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF1E52D4);

  Color get gamifSoftBlueCardBg =>
      _dark ? const Color(0xFF132133) : const Color(0xFFEEF3FA);

  Color get gamifInkCharcoal =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF37474F);

  Color get gamifFieldFillLight =>
      _dark ? const Color(0xFF18202E) : const Color(0xFFF2F4F8);

  Color get gamifMutedLabelGrey =>
      _dark ? const Color(0xFFACB0B8) : const Color(0xFF6B7280);

  Color get gamifTierLockedIconGrey =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFFB0BEC5);

  Color get gamifLegendGradientEnd =>
      _dark ? const Color(0xFFC9AFE8) : const Color(0xFF4A148C);

  Color get gamifInkSlateDark =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF455A64);

  Color get gamifPointConfigScreenBg =>
      _dark ? const Color(0xFF151A26) : const Color(0xFFF8F9FB);

  Color get gamifPointConfigOrangeAccent =>
      _dark ? const Color(0xFFE6B769) : const Color(0xFFF5A623);

  Color get gamifPointConfigActiveBadgeBg =>
      _dark ? const Color(0xFF332013) : const Color(0xFFFFE4D1);

  Color get gamifPointConfigActiveBadgeInk =>
      _dark ? const Color(0xFFDAC6BD) : const Color(0xFF5C4033);

  Color get gamifPointConfigHebrewSubtitleBlue =>
      _dark ? const Color(0xFF7BAAD5) : const Color(0xFF5B9BD5);

  Color get gamifPointConfigHeroBlueTop =>
      _dark ? const Color(0xFFAFC0E8) : const Color(0xFF002D9C);

  Color get gamifPointConfigHeroBlueBottom =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF001F6E);

  Color get gamifPointConfigChipUnselectedBg =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE8EBF0);

  Color get gamifCardShadowNavySoft =>
      _dark ? const Color(0x19000000) : const Color(0x1200218D);

  Color get gamifLegendGradientStart =>
      _dark ? const Color(0xFFAFB4E8) : const Color(0xFF1A237E);

  Color get gamifLegendCardShadow =>
      _dark ? const Color(0x5F000000) : const Color(0x441A237E);

  Color get gamifPartyColorCoral =>
      _dark ? const Color(0xFFE66969) : const Color(0xFFFF6B6B);

  Color get gamifPartyColorYellow =>
      _dark ? const Color(0xFF332D13) : const Color(0xFFFFD93D);

  Color get gamifPartyColorPink =>
      _dark ? const Color(0xFFE669D7) : const Color(0xFFFF9FF3);

  Color get gamifPartyColorOrange =>
      _dark ? const Color(0xFFE6BA69) : const Color(0xFFFFA502);

  Color get gamifPartyColorPurple =>
      _dark ? const Color(0xFFC2AFE8) : const Color(0xFF5F27CD);

  Color get gamifUnlockCardGradientCream =>
      _dark ? const Color(0xFF332813) : const Color(0xFFFFF4E0);

  Color get gamifUnlockCardGradientPink =>
      _dark ? const Color(0xFF331324) : const Color(0xFFFFE0F0);

  Color get gamifUnlockCardShadow =>
      _dark ? const Color(0x6B000000) : const Color(0x4D0038A8);

  Color get gamifLockedShellInkDeepest =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF263238);

  Color get gamifProTipCardBg =>
      _dark ? const Color(0xFF332713) : const Color(0xFFFFEFD5);

  Color get gamifProTipBorder =>
      _dark ? const Color(0xFF332613) : const Color(0xFFFFCC80);

  Color get gamifProTipShadow =>
      _dark ? const Color(0x1C000000) : const Color(0x14000000);

  Color get gamifProTipTitleText =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF212121);

  Color get gamifTrackFilterChipUnselected =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE0E4E8);

  Color get gamifTrackFilterChipShadow =>
      _dark ? const Color(0x2F000000) : const Color(0x220038A8);

  Color get gamifTierBronzeCardBg =>
      _dark ? const Color(0xFF332513) : const Color(0xFFF5E6D3);

  Color get gamifTierBronzeBorder =>
      _dark ? const Color(0xFF332214) : const Color(0xFFE8D5C4);

  Color get gamifTierBronzeIconAccent =>
      _dark ? const Color(0xFFBEACA6) : const Color(0xFF8D6E63);

  Color get gamifTierBronzeDeepAccent =>
      _dark ? const Color(0xFFD8C5BF) : const Color(0xFF6D4C41);

  Color get gamifTierBronzeTitle =>
      _dark ? const Color(0xFFD9C3BE) : const Color(0xFF4E342E);

  Color get gamifTierBronzeSoftAccent =>
      _dark ? const Color(0xFF332613) : const Color(0xFFFFE0B2);

  Color get gamifTierBronzeTagFg =>
      _dark ? const Color(0xFFE9957B) : const Color(0xFFBF360C);

  Color get gamifTierBronzeLockIcon =>
      _dark ? const Color(0xFFD9C5BE) : const Color(0xFF5D4037);

  Color get gamifTierSilverBorder =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFECEFF1);

  Color get gamifTierSilverBarBg =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE8ECEF);

  Color get gamifTierSilverBarFill =>
      _dark ? const Color(0xFFA6B7BE) : const Color(0xFF546E7A);

  Color get gamifTierSilverTagBg =>
      _dark ? const Color(0xFF1E2529) : const Color(0xFFCFD8DC);

  Color get gamifTierSilverLockIcon =>
      _dark ? const Color(0xFFA6B6BE) : const Color(0xFF607D8B);

  Color get gamifTierGoldCardBg =>
      _dark ? const Color(0xFF332C13) : const Color(0xFFFFF9E6);

  Color get gamifTierGoldBorder =>
      _dark ? const Color(0xFF332B13) : const Color(0xFFFFECB3);

  Color get gamifTierGoldIconBg =>
      _dark ? const Color(0xFF332C13) : const Color(0xFFFFC400);

  Color get gamifTierGoldTitle =>
      _dark ? const Color(0xFFE6A469) : const Color(0xFFB25707);

  Color get gamifTierGoldMutedIcon =>
      _dark ? const Color(0xFFE6C169) : const Color(0xFFFFB300);

  Color get gamifTierGoldBarBg =>
      _dark ? const Color(0xFF332B13) : const Color(0xFFFFE082);

  Color get gamifTierGoldBarFill =>
      _dark ? const Color(0xFFE6AF69) : const Color(0xFFFF8F00);

  Color get gamifTierGoldTagBg =>
      _dark ? const Color(0xFF332D13) : const Color(0xFFFFF3C4);

  Color get gamifTierGoldLockIcon =>
      _dark ? const Color(0xFFE6B769) : const Color(0xFFF9A825);

  Color get gamifTierPlatinumCardBg =>
      _dark ? const Color(0xFF132033) : const Color(0xFFFAFCFF);

  Color get gamifTierPlatinumSoftAccent =>
      _dark ? const Color(0xFF132533) : const Color(0xFFBBDEFB);

  Color get gamifTierPlatinumIconBg =>
      _dark ? const Color(0xFF132633) : const Color(0xFFE3F2FD);

  Color get gamifTierPlatinumIconFg =>
      _dark ? const Color(0xFF69AEE6) : const Color(0xFF0A6FC1);

  Color get gamifTierPlatinumMidAccent =>
      _dark ? const Color(0xFF69AFE6) : const Color(0xFF64B5F6);

  Color get gamifTierPlatinumTitle =>
      _dark ? const Color(0xFF7CAFE8) : const Color(0xFF1565C0);

  Color get gamifTierPlatinumBarFill =>
      _dark ? const Color(0xFF7BB8E9) : const Color(0xFF2196F3);

  Color get gamifTierPlatinumTagBg =>
      _dark ? const Color(0xFF132933) : const Color(0xFFE1F5FE);

  Color get gamifTierPlatinumTagFg =>
      _dark ? const Color(0xFF7BC0E9) : const Color(0xFF0173B7);

  Color get gamifTierPlatinumLockIcon =>
      _dark ? const Color(0xFF949DD0) : const Color(0xFF5C6BC0);

  Color get gamifTierPremiumCardBg =>
      _dark ? const Color(0xFF2F1333) : const Color(0xFFF3E5F5);

  Color get gamifTierPremiumSoftAccent =>
      _dark ? const Color(0xFF2F1333) : const Color(0xFFE1BEE7);

  Color get gamifTierPremiumIconBg =>
      _dark ? const Color(0xFF201333) : const Color(0xFFEDE7F6);

  Color get gamifTierPremiumIconFg =>
      _dark ? const Color(0xFFA993D1) : const Color(0xFF7B53C0);

  Color get gamifTierPremiumIconBorder =>
      _dark ? const Color(0xFF9E84CB) : const Color(0xFFB39DDB);

  Color get gamifTierPremiumTitle =>
      _dark ? const Color(0xFFBDAFE8) : const Color(0xFF4527A0);

  Color get gamifTierPremiumMutedIcon =>
      _dark ? const Color(0xFFA992D2) : const Color(0xFF9575CD);

  Color get gamifTierPremiumBarBg =>
      _dark ? const Color(0xFFC184CC) : const Color(0xFFCE93D8);

  Color get gamifTierPremiumBarFill =>
      _dark ? const Color(0xFFD7AFE8) : const Color(0xFF7B1FA2);

  Color get gamifTierPremiumLockIcon =>
      _dark ? const Color(0xFFD2AFE8) : const Color(0xFF6A1B9A);

  Color get gamifTierDiamondCardBg =>
      _dark ? const Color(0xFF132B33) : const Color(0xFFE0F7FF);

  Color get gamifTierDiamondSoftAccent =>
      _dark ? const Color(0xFF133033) : const Color(0xFF80DEEA);

  Color get gamifTierDiamondIconBg =>
      _dark ? const Color(0xFF133033) : const Color(0xFFE0F7FA);

  Color get gamifTierDiamondIconFg =>
      _dark ? const Color(0xFF69D8E6) : const Color(0xFF007887);

  Color get gamifTierDiamondIconBorder =>
      _dark ? const Color(0xFF72D2DE) : const Color(0xFF4DD0E1);

  Color get gamifTierDiamondTitle =>
      _dark ? const Color(0xFFAFE5E8) : const Color(0xFF006064);

  Color get gamifTierDiamondAccent =>
      _dark ? const Color(0xFF69D9E6) : const Color(0xFF00ACC1);

  Color get gamifTierDiamondTagBg =>
      _dark ? const Color(0xFF133033) : const Color(0xFFB2EBF2);

  Color get gamifTierDiamondTagFg =>
      _dark ? const Color(0xFF7BE0E9) : const Color(0xFF006B75);

  Color get gamifTierEliteCardBg =>
      _dark ? const Color(0xFF33131E) : const Color(0xFFFCE4EC);

  Color get gamifTierEliteSoftAccent =>
      _dark ? const Color(0xFF33131E) : const Color(0xFFF8BBD0);

  Color get gamifTierEliteIconFg =>
      _dark ? const Color(0xFFE97BA0) : const Color(0xFFEC407A);

  Color get gamifTierEliteIconBorder =>
      _dark ? const Color(0xFFE66993) : const Color(0xFFF48FB1);

  Color get gamifTierEliteDeepAccent =>
      _dark ? const Color(0xFFE8AFC8) : const Color(0xFFAD1457);

  Color get gamifTierEliteMutedIcon =>
      _dark ? const Color(0xFFE97BA0) : const Color(0xFFF06292);

  Color get gamifTierEliteBarFill =>
      _dark ? const Color(0xFFE97BA0) : const Color(0xFFE91E63);

  Color get gamifTierEliteLockIcon =>
      _dark ? const Color(0xFFE67EA7) : const Color(0xFFC2185B);

  Color get gamifTierCustomBorder =>
      _dark ? const Color(0xFF263041) : const Color(0xFFE0E0E0);

  Color get gamifTierCustomIconBg =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFF5F5F5);

  /// Streak-calendar / monthly-activity "active day" fill (was independently
  /// retyped as `const activeColor = Color(0xFF103BAC)` in both
  /// streak_calendar.dart and monthly_activity_sliver_calendar.dart).
  Color get progressStreakActiveDay =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF103BAC);

  /// Streak-calendar "today" ring colour drawn on an inactive day cell.
  Color get progressStreakTodayRing =>
      _dark ? const Color(0xFF9AA2B6) : const Color(0xFF9FA8BD);

  /// Lifetime-folder tree-node / marking-row "partial" state fill (was
  /// independently retyped at two call sites in
  /// lifetime_folder_styled_widgets.dart).
  Color get progressLifetimePartial =>
      _dark ? const Color(0xFF332A13) : const Color(0xFFFFD26A);

  /// Lifetime-folder marking-row "none" state fill on a light surface.
  Color get progressLifetimeNoneOnLight =>
      _dark ? const Color(0xFF36425A) : const Color(0xFFB8C0CC);

  /// Points-over-time bar-chart fill.
  Color get progressPointsBarFill =>
      _dark ? const Color(0xFF332713) : const Color(0xFFF2D9B3);

  /// Progress/dashboard shared tier-counter row — streak accent.
  Color get progressTierStreakAccent =>
      _dark ? const Color(0xFFE66970) : const Color(0xFFFF6F77);

  /// Progress/dashboard shared tier-counter row — points accent.
  Color get progressTierPointsAccent =>
      _dark ? const Color(0xFFE6C269) : const Color(0xFFE4A100);

  /// Siyumim "curriculum complete" hero card — dark-amber text, paired with
  /// [gamifTierGoldMutedIcon] (same gold reused for the hero card's
  /// fill/border/icon — see siyumim_grouped_view.dart).
  Color get progressSiyumHeroText =>
      _dark ? const Color(0xFFE8D4AF) : const Color(0xFF7A4F00);

  /// Limud/chazara stacked-bar chart — chazara (review-segment) colour.
  Color get progressChazaraSegment =>
      _dark ? const Color(0xFFE6B469) : const Color(0xFFF2A93B);

  /// Limud/chazara bar chart — weekday-axis label colour.
  Color get progressBarAxisLabel =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF8A91A5);

  /// Limud/chazara bar chart — legend label colour.
  Color get progressBarLegendLabel =>
      _dark ? const Color(0xFFAAAFBA) : const Color(0xFF5E6678);

  /// Lifetime-folder card gradient — top-left stop (deep blue).
  Color get progressLifetimeCardGradientStart =>
      _dark ? const Color(0xFFAFC3E8) : const Color(0xFF153E8C);

  /// Lifetime-folder card gradient — bottom-right stop (bright blue).
  Color get progressLifetimeCardGradientEnd =>
      _dark ? const Color(0xFF84AAE0) : const Color(0xFF3D7DDA);

  /// Lifetime-folder page-background gradient — top stop.
  Color get progressLifetimePageBgTop =>
      _dark ? const Color(0xFF131F33) : const Color(0xFFE8EEF8);

  /// Lifetime-folder page-background gradient — middle stop.
  Color get progressLifetimePageBgMid =>
      _dark ? const Color(0xFF131F33) : const Color(0xFFF2F6FD);

  /// Lifetime-folder page-background gradient — bottom stop.
  Color get progressLifetimePageBgBottom =>
      _dark ? const Color(0xFF131C33) : const Color(0xFFF8FAFF);

  /// Lifetime-folder Settings app bar (forest charcoal, no blue).
  Color get progressSettingsAppBar =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF2C382F);

  /// Lifetime-folder Settings page-background gradient — top stop (warm paper
  /// tone, no blue).
  Color get progressSettingsPageBgTop =>
      _dark ? const Color(0xFF263041) : const Color(0xFFEDE8E1);

  /// Lifetime-folder Settings page-background gradient — middle stop.
  Color get progressSettingsPageBgMid =>
      _dark ? const Color(0xFF2E2818) : const Color(0xFFF4F1EA);

  /// Lifetime-folder Settings page-background gradient — bottom stop.
  Color get progressSettingsPageBgBottom =>
      _dark ? const Color(0xFF2F2617) : const Color(0xFFFAF8F5);

  /// Lifetime-folder Settings card gradient — top-left stop (forest/sage,
  /// matches the growth metaphor, no blue).
  Color get progressSettingsCardGradientStart =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF263529);

  /// Lifetime-folder Settings card gradient — middle stop.
  Color get progressSettingsCardGradientMid =>
      _dark ? const Color(0xFFEAEEF5) : const Color(0xFF3A5240);

  /// Lifetime-folder Settings card gradient — bottom-right stop.
  Color get progressSettingsCardGradientEnd =>
      _dark ? const Color(0xFFAABAAD) : const Color(0xFF5C7560);

  /// [StatCard] highlighted-variant background (coral).
  Color get statCardHighlightCoral =>
      _dark ? const Color(0xFFE66970) : const Color(0xFFFF6E76);

  /// [StatCard] default (non-highlighted) value text colour.
  Color get statCardValueInk =>
      _dark ? const Color(0xFFB5C1E2) : const Color(0xFF11182C);

  /// [StatCard] default (non-highlighted) label text colour.
  Color get statCardLabelMuted =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF7C8595);

  /// Subtitle text colour shared by [PreferenceListTile] and
  /// [PreferenceSegmentedTile] — was independently hand-typed as the
  /// identical hex literal in both files.
  Color get preferenceSubtitleGrey =>
      _dark ? const Color(0xFF98A2B3) : const Color(0xFF929BAA);

  /// [PreferenceSegmentedTile] header-row title text colour.
  Color get preferenceTitleInk =>
      _dark ? const Color(0xFFBEC7D9) : const Color(0xFF1D2432);

  /// [PreferenceSegmentedTile]'s [SegmentedButton] unselected border colour.
  Color get preferenceSegmentedBorder =>
      _dark ? const Color(0xFF18202E) : const Color(0xFFD7DEEA);

  /// [showAppConfirmDialog]'s cancel-button background (light mode).
  Color get dialogCancelButtonBg =>
      _dark ? const Color(0xFF1E2532) : const Color(0xFFF0F1F5);

  /// Lock-overlay background — plain Shabbos window.
  Color get sacredTimeLockShabbosBg =>
      _dark ? const Color(0xFFAFBBE8) : const Color(0xFF11215C);

  /// Lock-overlay background — Shabbos + Yom Tov combined window.
  Color get sacredTimeLockShabbosYomTovBg =>
      _dark ? const Color(0xFFBBB2E5) : const Color(0xFF31246C);

  /// Lock-overlay background — Yom Kippur window.
  Color get sacredTimeLockYomKippurBg =>
      _dark ? const Color(0xFFBBC7DC) : const Color(0xFF1A2333);

  /// Settings-card header background, paired with the lock-badge icon.
  Color get sacredTimeHeaderBg =>
      _dark ? const Color(0xFFAFBFE8) : const Color(0xFF11389F);

  /// "PARENT" role-context badge background (pale blue).
  Color get settingsProfileBadgeParentBg =>
      _dark ? const Color(0xFF132533) : const Color(0xFFE8F4FD);

  /// "PARENT" role-context badge text, paired with
  /// [settingsProfileBadgeParentBg].
  Color get settingsProfileBadgeParentText =>
      _dark ? const Color(0xFF7CAFE8) : const Color(0xFF1565C0);

  /// "TUTOR" role-context badge background (pale amber). The tutor badge text
  /// reuses [accentBurntOrange] — same hex, already defined.
  Color get settingsProfileBadgeTutorBg =>
      _dark ? const Color(0xFF332713) : const Color(0xFFFFF3E0);

  /// Profile avatar circle's outer ring fill (shown before the avatar image
  /// loads / behind the initial-letter avatar).
  Color get settingsProfileAvatarRing =>
      _dark ? const Color(0xFF151F31) : const Color(0xFFCFD8EA);

  /// Settings-surface profile card drop-shadow (translucent navy-ink).
  Color get settingsProfileCardShadow =>
      _dark ? const Color(0x19000000) : const Color(0x121D2939);

  /// Parent-mode-surface profile card drop-shadow (translucent brand blue).
  Color get settingsProfileParentCardShadow =>
      _dark ? const Color(0x1C000000) : const Color(0x140038A8);

  /// Offline "no backup" cloud-off icon + inline warning text (amber-brown).
  Color get settingsProfileNoBackupAccent =>
      _dark ? const Color(0xFFD5A97B) : const Color(0xFFCE8A41);

  /// Fully transparent.
  Color get transparent => const Color(0x00000000);

  /// Brightness-aware identity colour for a curriculum.
  ///
  /// Replaces `AppTheme.getCurriculumColor`, whose values were fixed light
  /// tones that sank into the dark surface ramp.
  Color curriculumFor(CurriculumId curriculum) => switch (curriculum) {
    CurriculumId.mishnayos => curriculumMishna,
    CurriculumId.bavli => curriculumBavli,
    CurriculumId.yerushalmi => curriculumYerushalmi,
    CurriculumId.mishnaBerurah => curriculumMishnaBerurah,
    CurriculumId.chumash => curriculumChumash,
    CurriculumId.mishnehTorah => curriculumMussar,
    CurriculumId.tanach => curriculumNach,
    CurriculumId.nach => curriculumNach,
    CurriculumId.mussar => curriculumMussar,
  };

  /// Brightness-aware curriculum colour looked up by storage key.
  Color curriculumForKey(String storageKey) {
    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == storageKey)
        .firstOrNull;
    return curriculum != null ? curriculumFor(curriculum) : brandBlue;
  }
}

/// Ergonomic access to [AppPalette] from any widget.
extension AppPaletteContext on BuildContext {
  /// The brightness-aware semantic colour palette for the ambient theme.
  AppPalette get colors => AppPalette.of(this);
}
