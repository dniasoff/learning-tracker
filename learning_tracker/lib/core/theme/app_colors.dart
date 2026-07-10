import 'package:flutter/material.dart';

/// Supplementary colour constants for feature-specific UI elements.
///
/// The canonical brand palette lives in [AppTheme] (app_theme.dart).
/// This file holds semantic colours that appear in feature presentation layers
/// but do not belong to the Material colour-scheme definition.
///
/// Naming convention:
///   - Functional groupings (status*, streak*, chart*, etc.)
///   - Light-palette constants only; dark variants are [<name>Dark]
///   - Alpha-variants use [withValues(alpha:)] at call site
///
/// Usage: import 'package:learning_tracker/core/theme/app_colors.dart';
abstract final class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Status / semantic
  // ---------------------------------------------------------------------------

  /// Generic error/danger red used in UI badges, streak-break indicators, etc.
  static const Color statusError = Color(0xFFD63C3C);

  /// Lighter error tint (badge backgrounds, alert backgrounds).
  static const Color statusErrorSoft = Color(0xFFFDE7EA);

  /// Slightly brighter danger red for notifications / overdue indicators.
  static const Color statusDanger = Color(0xFFF26666);

  /// Amber / warning amber (overdue-light, caution banners).
  static const Color statusWarning = Color(0xFFE9A42A);

  /// Warning background tint.
  static const Color statusWarningSoft = Color(0xFFFFF2CF);

  /// Success green for completion confirmations.
  static const Color statusSuccess = Color(0xFF22C55E);

  /// Muted success green (streak active, in-progress items).
  static const Color statusSuccessMuted = Color(0xFF3BDD87);

  /// Deep success green (siyum / full-track complete).
  static const Color statusSuccessDeep = Color(0xFF2E7D32);

  // ---------------------------------------------------------------------------
  // Neutral surface tones (extended beyond AppTheme.brandCream*)
  // ---------------------------------------------------------------------------

  /// Very light blue-grey surface — scaffold backgrounds, content screens.
  static const Color surfaceF5 = Color(0xFFF5F7FC);

  /// Light neutral surface for section backgrounds.
  static const Color surfaceF3 = Color(0xFFF3F4F8);

  /// Slightly warmer light neutral (step card backgrounds).
  static const Color surfaceF4 = Color(0xFFF4F5F8);

  /// Slightly different warm-neutral variant.
  static const Color surfaceF4b = Color(0xFFF4F6FB);

  /// Common widget tray / card surface — border colour and inactive backgrounds.
  static const Color surfaceE9 = Color(0xFFE9ECF2);

  /// Soft blue-tinted neutral (card tint, progress containers).
  static const Color surfaceBlueNeutral = Color(0xFFF0F2F8);

  /// Light lavender-blue tint (selected chip bg, blue-themed items).
  static const Color surfaceBlueLight = Color(0xFFE5E9FF);

  /// Light grey-blue (divider lines, outline borders).
  static const Color surfaceGreyBlue = Color(0xFFE2E6F0);

  // ---------------------------------------------------------------------------
  // Feature accent — blue shades (brand-adjacent, used in gradient stops,
  // selected states, deep backgrounds)
  // ---------------------------------------------------------------------------

  /// Deep brand-navy (gradient bottom, heavy chip backgrounds).
  static const Color blueNavy = Color(0xFF03174C);

  /// Dark navy variant used in deep screen gradients.
  static const Color blueDeepNavy = Color(0xFF0A2056);

  /// Bright medium blue (selected-tab highlight, step indicator active).
  static const Color blueMedium = Color(0xFF1C47C4);

  /// Slightly lighter mid-blue (button tints, tile borders).
  static const Color blueLight = Color(0xFF1639A8);

  /// Another mid-blue shade used in tracks-setup components.
  static const Color blueMid = Color(0xFF123DAE);

  // ---------------------------------------------------------------------------
  // Gamification — gold / amber / peach
  // ---------------------------------------------------------------------------

  /// Trophy gold (streak flame icon, milestone badge fill).
  static const Color goldTrophy = Color(0xFFFFC94A);

  /// Warm amber (point bubbles, reward-card header).
  static const Color goldAmber = Color(0xFFE9A42A);

  /// Dark amber / honey (text on gold backgrounds).
  static const Color goldDark = Color(0xFF7D5411);

  /// Warm peach tint (reward card body background).
  static const Color peachTint = Color(0xFFF9E4C8);

  /// Medium amber-peach (icon backgrounds on reward cards).
  static const Color peachMid = Color(0xFFF3D4A5);

  /// Peach amber-dark (reward card text).
  static const Color peachDark = Color(0xFF594624);

  /// Warning-tone soft yellow (overdue banners, reminder badges).
  static const Color warnYellow = Color(0xFFFFF2CF);

  // ---------------------------------------------------------------------------
  // Chart palette (used across progress / stats screens)
  // ---------------------------------------------------------------------------

  /// Chart series colour — primary blue.
  static const Color chartBlue = Color(0xFF4D96FF);

  /// Chart series colour — teal-cyan.
  static const Color chartTeal = Color(0xFF0097A7);

  /// Chart series colour — green.
  static const Color chartGreen = Color(0xFF6BCB77);

  /// Chart series colour — amber.
  static const Color chartAmber = Color(0xFFF8C146);

  /// Chart series colour — red.
  static const Color chartRed = Color(0xFFB43A4A);

  /// Chart bar background (empty bar).
  static const Color chartBarBg = Color(0xFF404060);

  /// Chart bar fill (inactive / muted).
  static const Color chartBarFillMuted = Color(0xFF9E9E9E);

  // ---------------------------------------------------------------------------
  // Streak / calendar specific
  // ---------------------------------------------------------------------------

  /// Streak active day fill (bright green).
  static const Color streakActive = Color(0xFF69F0AE);

  /// Streak empty / rest day (muted blue-grey).
  static const Color streakEmpty = Color(0xFF90A4AE);

  // ---------------------------------------------------------------------------
  // Content / text tones (beyond AppTheme.brandInk*)
  // ---------------------------------------------------------------------------

  /// Very dark ink (near-black) for display headings in dark containers.
  static const Color inkDeepDark = Color(0xFF1A1A1A);

  /// Standard dark slate used for body text on white cards.
  static const Color inkSlate = Color(0xFF4A5568);

  /// Mid-grey muted text (sub-labels, placeholders).
  static const Color inkMidGrey = Color(0xFF8E97A6);

  /// Light blue-grey icon colour.
  static const Color iconBlueGrey = Color(0xFF78909C);

  // ---------------------------------------------------------------------------
  // Misc accent tones (used one or a few times across feature screens;
  // gathered here to avoid per-file magic-number repetition)
  // ---------------------------------------------------------------------------

  /// Deep purple accent (mussar curriculum, some achievement icons).
  static const Color accentPurpleDeep = Color(0xFF4A2A8A);

  /// Teal-green accent (Nach / Yerushalmi identity icon).
  static const Color accentTealGreen = Color(0xFF1D7D73);

  /// Light teal surface for content-type chips.
  static const Color accentTealSoft = Color(0xFFE0F4FF);

  /// Coral/salmon for overdue / missed tasks.
  static const Color accentCoral = Color(0xFFF86B6B);

  /// Burnt-orange accent (warning chips, deadline chip).
  static const Color accentBurntOrange = Color(0xFFE65100);

  // ---------------------------------------------------------------------------
  // Semi-transparent overlays (common alpha masks)
  // ---------------------------------------------------------------------------

  /// Dark scrim overlay (0x40 ≈ 25 % opacity black).
  static const Color scrimDark = Color(0x40000000);

  /// Light scrim overlay.
  static const Color scrimLight = Color(0x33FFFFFF);

  // ---------------------------------------------------------------------------
  // Tutoring feature (AUD-tutoring-18) — status badges, PIN gate icon, and
  // the audit-log per-action categorical palette
  // ---------------------------------------------------------------------------

  /// Success-state card background (accept/rescind confirmation cards,
  /// tutor PIN reset success card).
  static const Color statusSuccessSoftBg = Color(0xFFEAF5EA);

  /// Success-state card text/icon colour, paired with [statusSuccessSoftBg].
  static const Color statusSuccessSoftText = Color(0xFF3A7C3A);

  /// Warning-state text/icon colour, paired with the existing
  /// [statusWarningSoft] background (decline/PIN-reset warning cards).
  static const Color statusWarningSoftText = Color(0xFFB07A00);

  /// Error-state card background (decline/accept error steps).
  static const Color statusErrorCardBg = Color(0xFFFFEBEE);

  /// Error-state card text/icon colour, paired with [statusErrorCardBg].
  static const Color statusErrorCardText = Color(0xFFE53935);

  /// "Active" status badge colour (active tutor grant / accepted invite).
  static const Color statusActiveBadge = Color(0xFF43A047);

  /// "Pending" status badge colour (pending tutor grant / invite).
  static const Color statusPendingBadge = Color(0xFFF57C00);

  /// Confirmation-snackbar success green (invite sent, etc.).
  static const Color statusSuccessSnackbar = Color(0xFF388E3C);

  /// Lavender PIN-badge circle background (Tutor PIN gate/setup/reset icon).
  static const Color tutorPinBadgeBg = Color(0xFFE8E0FF);

  /// Deep-purple icon colour, paired with [tutorPinBadgeBg].
  static const Color tutorPinBadgeIcon = Color(0xFF6B3FA0);

  /// Neutral border/fill for a disabled PIN keypad key.
  static const Color tutorPinKeyDisabled = Color(0xFFC9D0DA);

  /// Audit-log action category — config change.
  static const Color auditActionConfig = Color(0xFF1E88E5);

  /// Audit-log action category — bulk prior-completion mark.
  static const Color auditActionBulkPrior = Color(0xFF43A047);

  /// Audit-log action category — completion reset.
  static const Color auditActionReset = Color(0xFFF57C00);

  /// Audit-log action category — bookmark advanced.
  static const Color auditActionBookmark = Color(0xFF8E24AA);

  /// Audit-log action category — profile edited.
  static const Color auditActionProfileEdited = Color(0xFF00897B);

  /// Audit-log action category — goal changed.
  static const Color auditActionGoalChanged = Color(0xFF3949AB);

  /// Audit-log action category — stage changed.
  static const Color auditActionStageChanged = Color(0xFF0097A7);

  /// Audit-log action category — reward changed.
  static const Color auditActionRewardChanged = Color(0xFFFFA000);

  /// Audit-log action category — study-day changed.
  static const Color auditActionStudyDayChanged = Color(0xFFF4511E);

  // ---------------------------------------------------------------------------
  // App shell / navigation (AUD-app-03) — context banners, bottom nav, and the
  // persistent profile-switcher bar shared between app_shell.dart and
  // persistent_switcher_scaffold.dart.
  // ---------------------------------------------------------------------------

  /// Tutor-mode context banner background (W6.15) — a warm amber that
  /// contrasts with the app's primary blue to signal "you are in a
  /// different access context".
  static const Color tutorModeAccent = Color(0xFFD97706); // Amber-600

  /// Child-view context banner background (WS4.banner) — a teal/emerald
  /// green distinct from both the tutor amber and the primary blue,
  /// signalling "you are inside a child's profile, not your own".
  static const Color childViewAccent = Color(0xFF047857); // Emerald-700

  /// Shared opaque pale-blue background for the persistent profile-switcher
  /// bar. Referenced identically from app_shell.dart's ProfileSwitcherBar and
  /// persistent_switcher_scaffold.dart's status-bar inset wrapper so a future
  /// contrast fix only has one definition to update (see app_shell.dart's
  /// "Bug 7" / "Bug 7 (re-fix)" history — AUD-app-03).
  static const Color switcherBarBackground = Color(0xFFF1F3FA);

  /// Border colour paired with [switcherBarBackground].
  static const Color switcherBarBorder = Color(0xFFD7DEF0);

  /// Bottom-nav selected item background / active tab fill.
  static const Color navSelectedBlue = Color(0xFF0038A8);

  /// Bottom-nav bar drop shadow — [navSelectedBlue] at ~8% alpha.
  static const Color navBarShadow = Color(0x140038A8);

  /// Selected nav-item drop shadow — [navSelectedBlue] at 20% alpha.
  static const Color navItemSelectedShadow = Color(0x330038A8);

  /// Unselected bottom-nav icon/label colour (slate grey).
  static const Color navUnselectedText = Color(0xFF708090);
}
