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

  // ---------------------------------------------------------------------------
  // Onboarding intro carousel (AUD-onboarding-13) — was independently
  // hand-typed as a private `_kNavy` etc. constant in each of
  // intro_mishna_page.dart, intro_page_indicator.dart,
  // intro_rewards_page.dart, glowing_cta_button.dart and
  // intro_daily_plan_page.dart; centralised here so the five copies cannot
  // drift out of sync on a future rebrand/dark-mode pass.
  // ---------------------------------------------------------------------------

  /// Deep navy used for the intro carousel's hero card fill, chip text, and
  /// accent text (was duplicated as `_kNavy` in 5 files).
  static const Color introNavy = Color(0xFF1A36A5);

  /// Soft peach used for the Mishna/Rewards illustration accent chips.
  static const Color introPeach = Color(0xFFFFD8C8);

  /// Pale blue pill background for the Mishna "review" chip.
  static const Color introPillBlue = Color(0xFFC8D8F8);

  /// Unfilled track colour for the intro progress bars.
  static const Color introProgressTrackBg = Color(0xFFE2E5EB);

  /// Filled/active colour for the intro progress bars (Mishna page bar and
  /// the Rewards page's scholar-level example bar).
  static const Color introProgressFillGreen = Color(0xFF1DB97D);

  /// Border colour for the Rewards page's "Mystery Prizes" feature card.
  static const Color introMysteryBorder = Color(0xFFC9A86A);

  /// Circle background behind the Rewards page's "Badge Collection" icon
  /// and the child-mode tag icon.
  static const Color introBadgeBg = Color(0xFFE8ECFF);

  /// Circle background behind the Rewards page's "Mystery Prizes" icon.
  static const Color introMysteryBg = Color(0xFFFFF3E0);

  /// Text colour on the "Mystery Prizes" feature card.
  static const Color introMysteryText = Color(0xFF5C4A2A);

  /// Icon colour on the "Mystery Prizes" feature card.
  static const Color introMysteryIcon = Color(0xFF6B4E1E);

  /// Drop-shadow colour for the Rewards page's streak badge.
  static const Color introCardShadow = Color(0x2E000000);

  /// Unfilled track colour for the Rewards page's scholar-level example bar.
  static const Color introScholarTrackBg = Color(0xFFE8EAEF);

  /// Inactive-dot colour for the intro page indicator.
  static const Color introIndicatorInactive = Color(0xFFDCE0EA);

  /// Third "window dot" accent (sky blue) in the daily-plan illustration's
  /// mock browser-chrome header.
  static const Color introWindowDotBlue = Color(0xFF5BC0EB);

  /// Pill-shaped row background for the daily-plan illustration's checked
  /// and empty task rows.
  static const Color introDailyRowPillBg = Color(0xFFF0F1F4);

  /// Filled track colour for the daily-plan illustration's checked-row
  /// progress bar and the first "empty" row variant.
  static const Color introDailyRowTrackFilled = Color(0xFFDCDFE5);

  /// Border colour for the daily-plan illustration's unchecked checkbox
  /// circle.
  static const Color introDailyCheckboxBorder = Color(0xFFC9CED6);

  /// Unfilled track colour for the daily-plan illustration's second "empty"
  /// row variant.
  static const Color introDailyRowTrackEmpty = Color(0xFFE5E7EC);

  // ---------------------------------------------------------------------------
  // Notifications settings screen (AUD-notifications-12) — daily-reminder /
  // streak-alert / reward-milestone row icon tints+backgrounds, shared text
  // tones, the "HOT STREAK" badge, and the device-level OS toggle's track
  // colours. Centralised here so notifications_screen.dart and
  // device_notification_toggle.dart no longer hand-type hex literals
  // alongside their existing AppColors/AppTheme usage.
  // ---------------------------------------------------------------------------

  /// "Daily Reminder" row icon tint (blue).
  static const Color notifReminderIconTint = Color(0xFF2A4BB3);

  /// "Daily Reminder" row icon background, paired with
  /// [notifReminderIconTint].
  static const Color notifReminderIconBg = Color(0xFFE8EBFF);

  /// "Streak Alert" row icon tint (coral).
  static const Color notifStreakIconTint = Color(0xFFE35D66);

  /// "Streak Alert" row icon background, paired with [notifStreakIconTint].
  static const Color notifStreakIconBg = Color(0xFFFDECEF);

  /// "Reward Milestones" row icon tint (amber).
  static const Color notifRewardIconTint = Color(0xFFB07A2A);

  /// "Reward Milestones" row icon background, paired with
  /// [notifRewardIconTint].
  static const Color notifRewardIconBg = Color(0xFFFDF2DE);

  /// Settings-group card drop shadow (translucent navy, ~7% alpha).
  static const Color notifCardShadow = Color(0x12061D56);

  /// Primary row-title text colour (near-black).
  static const Color notifTitleText = Color(0xFF151B2D);

  /// Secondary/subtitle text colour — shared by the settings-row subtitles
  /// and the device-level toggle's status subtitle.
  static const Color notifSubtitleText = Color(0xFF7A8293);

  /// Enabled time-row text colour (reminder/streak time-picker rows).
  static const Color notifTimeTextEnabled = Color(0xFF1A2340);

  /// Disabled time-row text colour.
  static const Color notifTimeTextDisabled = Color(0xFF9CA3B4);

  /// "HOT STREAK" top-badge background.
  static const Color notifHotStreakBadge = Color(0xFFFF6A78);

  /// Device-level OS toggle active track colour.
  static const Color notifDeviceToggleActiveTrack = Color(0xFF123CA5);

  /// Device-level OS toggle inactive track colour.
  static const Color notifDeviceToggleInactiveTrack = Color(0xFFE0E4ED);

  // ---------------------------------------------------------------------------
  // Gamification feature (AUD-gamification-21) -- achievement tier palette
  // (TierStyle.forTier's bronze/silver/gold/platinum/premium/diamond/elite/
  // custom tiers), reward/points-config screens, the unlock-celebration party
  // dialog, and shared field-fill/label tones. Centralised here so no
  // lib/features/gamification/**/*.dart file embeds a raw Color(0x...) literal.
  // ---------------------------------------------------------------------------

  static const Color gamifChildRewardsCardBlueTop = Color(0xFF1E52D4);
  static const Color gamifSoftBlueCardBg = Color(0xFFEEF3FA);
  static const Color gamifInkCharcoal = Color(0xFF37474F);
  static const Color gamifFieldFillLight = Color(0xFFF2F4F8);
  static const Color gamifMutedLabelGrey = Color(0xFF6B7280);
  static const Color gamifTierLockedIconGrey = Color(0xFFB0BEC5);
  static const Color gamifLegendGradientEnd = Color(0xFF4A148C);
  static const Color gamifInkSlateDark = Color(0xFF455A64);
  static const Color gamifPointConfigScreenBg = Color(0xFFF8F9FB);
  static const Color gamifPointConfigOrangeAccent = Color(0xFFF5A623);
  static const Color gamifPointConfigActiveBadgeBg = Color(0xFFFFE4D1);
  static const Color gamifPointConfigActiveBadgeInk = Color(0xFF5C4033);
  static const Color gamifPointConfigHebrewSubtitleBlue = Color(0xFF5B9BD5);
  static const Color gamifPointConfigHeroBlueTop = Color(0xFF002D9C);
  static const Color gamifPointConfigHeroBlueBottom = Color(0xFF001F6E);
  static const Color gamifPointConfigChipUnselectedBg = Color(0xFFE8EBF0);
  static const Color gamifCardShadowNavySoft = Color(0x1200218D);
  static const Color gamifLegendGradientStart = Color(0xFF1A237E);
  static const Color gamifLegendCardShadow = Color(0x441A237E);
  static const Color gamifPartyColorCoral = Color(0xFFFF6B6B);
  static const Color gamifPartyColorYellow = Color(0xFFFFD93D);
  static const Color gamifPartyColorPink = Color(0xFFFF9FF3);
  static const Color gamifPartyColorOrange = Color(0xFFFFA502);
  static const Color gamifPartyColorPurple = Color(0xFF5F27CD);
  static const Color gamifUnlockCardGradientCream = Color(0xFFFFF4E0);
  static const Color gamifUnlockCardGradientPink = Color(0xFFFFE0F0);
  static const Color gamifUnlockCardShadow = Color(0x4D0038A8);
  static const Color gamifLockedShellInkDeepest = Color(0xFF263238);
  static const Color gamifProTipCardBg = Color(0xFFFFEFD5);
  static const Color gamifProTipBorder = Color(0xFFFFCC80);
  static const Color gamifProTipShadow = Color(0x14000000);
  static const Color gamifProTipTitleText = Color(0xFF212121);
  static const Color gamifTrackFilterChipUnselected = Color(0xFFE0E4E8);
  static const Color gamifTrackFilterChipShadow = Color(0x220038A8);
  static const Color gamifTierBronzeCardBg = Color(0xFFF5E6D3);
  static const Color gamifTierBronzeBorder = Color(0xFFE8D5C4);
  static const Color gamifTierBronzeIconAccent = Color(0xFF8D6E63);
  static const Color gamifTierBronzeDeepAccent = Color(0xFF6D4C41);
  static const Color gamifTierBronzeTitle = Color(0xFF4E342E);
  static const Color gamifTierBronzeSoftAccent = Color(0xFFFFE0B2);
  static const Color gamifTierBronzeTagFg = Color(0xFFBF360C);
  static const Color gamifTierBronzeLockIcon = Color(0xFF5D4037);
  static const Color gamifTierSilverBorder = Color(0xFFECEFF1);
  static const Color gamifTierSilverBarBg = Color(0xFFE8ECEF);
  static const Color gamifTierSilverBarFill = Color(0xFF546E7A);
  static const Color gamifTierSilverTagBg = Color(0xFFCFD8DC);
  static const Color gamifTierSilverLockIcon = Color(0xFF607D8B);
  static const Color gamifTierGoldCardBg = Color(0xFFFFF9E6);
  static const Color gamifTierGoldBorder = Color(0xFFFFECB3);
  static const Color gamifTierGoldIconBg = Color(0xFFFFC400);
  static const Color gamifTierGoldTitle = Color(0xFFF57F17);
  static const Color gamifTierGoldMutedIcon = Color(0xFFFFB300);
  static const Color gamifTierGoldBarBg = Color(0xFFFFE082);
  static const Color gamifTierGoldBarFill = Color(0xFFFF8F00);
  static const Color gamifTierGoldTagBg = Color(0xFFFFF3C4);
  static const Color gamifTierGoldLockIcon = Color(0xFFF9A825);
  static const Color gamifTierPlatinumCardBg = Color(0xFFFAFCFF);
  static const Color gamifTierPlatinumSoftAccent = Color(0xFFBBDEFB);
  static const Color gamifTierPlatinumIconBg = Color(0xFFE3F2FD);
  static const Color gamifTierPlatinumIconFg = Color(0xFF42A5F5);
  static const Color gamifTierPlatinumMidAccent = Color(0xFF64B5F6);
  static const Color gamifTierPlatinumTitle = Color(0xFF1565C0);
  static const Color gamifTierPlatinumBarFill = Color(0xFF2196F3);
  static const Color gamifTierPlatinumTagBg = Color(0xFFE1F5FE);
  static const Color gamifTierPlatinumTagFg = Color(0xFF0277BD);
  static const Color gamifTierPlatinumLockIcon = Color(0xFF5C6BC0);
  static const Color gamifTierPremiumCardBg = Color(0xFFF3E5F5);
  static const Color gamifTierPremiumSoftAccent = Color(0xFFE1BEE7);
  static const Color gamifTierPremiumIconBg = Color(0xFFEDE7F6);
  static const Color gamifTierPremiumIconFg = Color(0xFF7E57C2);
  static const Color gamifTierPremiumIconBorder = Color(0xFFB39DDB);
  static const Color gamifTierPremiumTitle = Color(0xFF4527A0);
  static const Color gamifTierPremiumMutedIcon = Color(0xFF9575CD);
  static const Color gamifTierPremiumBarBg = Color(0xFFCE93D8);
  static const Color gamifTierPremiumBarFill = Color(0xFF7B1FA2);
  static const Color gamifTierPremiumLockIcon = Color(0xFF6A1B9A);
  static const Color gamifTierDiamondCardBg = Color(0xFFE0F7FF);
  static const Color gamifTierDiamondSoftAccent = Color(0xFF80DEEA);
  static const Color gamifTierDiamondIconBg = Color(0xFFE0F7FA);
  static const Color gamifTierDiamondIconFg = Color(0xFF00BCD4);
  static const Color gamifTierDiamondIconBorder = Color(0xFF4DD0E1);
  static const Color gamifTierDiamondTitle = Color(0xFF006064);
  static const Color gamifTierDiamondAccent = Color(0xFF00ACC1);
  static const Color gamifTierDiamondTagBg = Color(0xFFB2EBF2);
  static const Color gamifTierDiamondTagFg = Color(0xFF00838F);
  static const Color gamifTierEliteCardBg = Color(0xFFFCE4EC);
  static const Color gamifTierEliteSoftAccent = Color(0xFFF8BBD0);
  static const Color gamifTierEliteIconFg = Color(0xFFEC407A);
  static const Color gamifTierEliteIconBorder = Color(0xFFF48FB1);
  static const Color gamifTierEliteDeepAccent = Color(0xFFAD1457);
  static const Color gamifTierEliteMutedIcon = Color(0xFFF06292);
  static const Color gamifTierEliteBarFill = Color(0xFFE91E63);
  static const Color gamifTierEliteLockIcon = Color(0xFFC2185B);
  static const Color gamifTierCustomBorder = Color(0xFFE0E0E0);
  static const Color gamifTierCustomIconBg = Color(0xFFF5F5F5);

  // ---------------------------------------------------------------------------
  // Progress feature (AUD-progress-04) — streak calendar active-day fill,
  // lifetime-folder gradients/state colours, points/streak tier-counter
  // accents, and the limud/chazara bar-chart axis tones. Centralised here so
  // no lib/features/progress/**/*.dart widget file embeds a raw
  // Color(0x...) literal; the identical streak-active blue and lifetime
  // partial-amber were previously hand-retyped in two files/call-sites each.
  // ---------------------------------------------------------------------------

  /// Streak-calendar / monthly-activity "active day" fill (was independently
  /// retyped as `const activeColor = Color(0xFF103BAC)` in both
  /// streak_calendar.dart and monthly_activity_sliver_calendar.dart).
  static const Color progressStreakActiveDay = Color(0xFF103BAC);

  /// Streak-calendar "today" ring colour drawn on an inactive day cell.
  static const Color progressStreakTodayRing = Color(0xFF9FA8BD);

  /// Lifetime-folder tree-node / marking-row "partial" state fill (was
  /// independently retyped at two call sites in
  /// lifetime_folder_styled_widgets.dart).
  static const Color progressLifetimePartial = Color(0xFFFFD26A);

  /// Lifetime-folder marking-row "none" state fill on a light surface.
  static const Color progressLifetimeNoneOnLight = Color(0xFFB8C0CC);

  /// Points-over-time bar-chart fill.
  static const Color progressPointsBarFill = Color(0xFFF2D9B3);

  /// Progress/dashboard shared tier-counter row — streak accent.
  static const Color progressTierStreakAccent = Color(0xFFFF6F77);

  /// Progress/dashboard shared tier-counter row — points accent.
  static const Color progressTierPointsAccent = Color(0xFFE4A100);

  /// Siyumim "curriculum complete" hero card — dark-amber text, paired with
  /// [gamifTierGoldMutedIcon] (same gold reused for the hero card's
  /// fill/border/icon — see siyumim_grouped_view.dart).
  static const Color progressSiyumHeroText = Color(0xFF7A4F00);

  /// Limud/chazara stacked-bar chart — chazara (review-segment) colour.
  static const Color progressChazaraSegment = Color(0xFFF2A93B);

  /// Limud/chazara bar chart — weekday-axis label colour.
  static const Color progressBarAxisLabel = Color(0xFF8A91A5);

  /// Limud/chazara bar chart — legend label colour.
  static const Color progressBarLegendLabel = Color(0xFF5E6678);

  /// Lifetime-folder card gradient — top-left stop (deep blue).
  static const Color progressLifetimeCardGradientStart = Color(0xFF153E8C);

  /// Lifetime-folder card gradient — bottom-right stop (bright blue).
  static const Color progressLifetimeCardGradientEnd = Color(0xFF3D7DDA);

  /// Lifetime-folder page-background gradient — top stop.
  static const Color progressLifetimePageBgTop = Color(0xFFE8EEF8);

  /// Lifetime-folder page-background gradient — middle stop.
  static const Color progressLifetimePageBgMid = Color(0xFFF2F6FD);

  /// Lifetime-folder page-background gradient — bottom stop.
  static const Color progressLifetimePageBgBottom = Color(0xFFF8FAFF);

  /// Lifetime-folder Settings app bar (forest charcoal, no blue).
  static const Color progressSettingsAppBar = Color(0xFF2C382F);

  /// Lifetime-folder Settings page-background gradient — top stop (warm
  /// paper tone, no blue).
  static const Color progressSettingsPageBgTop = Color(0xFFEDE8E1);

  /// Lifetime-folder Settings page-background gradient — middle stop.
  static const Color progressSettingsPageBgMid = Color(0xFFF4F1EA);

  /// Lifetime-folder Settings page-background gradient — bottom stop.
  static const Color progressSettingsPageBgBottom = Color(0xFFFAF8F5);

  /// Lifetime-folder Settings card gradient — top-left stop (forest/sage,
  /// matches the growth metaphor, no blue).
  static const Color progressSettingsCardGradientStart = Color(0xFF263529);

  /// Lifetime-folder Settings card gradient — middle stop.
  static const Color progressSettingsCardGradientMid = Color(0xFF3A5240);

  /// Lifetime-folder Settings card gradient — bottom-right stop.
  static const Color progressSettingsCardGradientEnd = Color(0xFF5C7560);
}
