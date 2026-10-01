# Current Flutter UI identity and inventory

Snapshot: source under `learning_tracker/lib/` as inspected 2026-09-30. This is a source inventory; citations use repository-relative `file:line` references. The app uses AutoRoute and Material widgets; generated route declarations are in `learning_tracker/lib/app/router/app_router.gr.dart:1`, while route registration is in `learning_tracker/lib/app/router/app_router.dart:55`.

## 1. Theme & tokens

### Theme construction and colors

- Material 3 is enabled. `AppTheme` supplies light and dark `ThemeData`; app startup selects light or dark using `ThemeMode.system`, and the active profile's child mode is passed to the light-theme factory (`learning_tracker/lib/core/theme/app_theme.dart:67-77`, `:108-112`; `learning_tracker/lib/app/learning_tracker_app.dart:63-76`). The `isChildMode` parameter is accepted but both factories currently build the same palette (`app_theme.dart:67-77`).
- The default primary/seed-equivalent is royal blue: light `#1442B8`, dark `#7CA0FF`. This is passed as `ColorScheme.primary`; this app constructs `ColorScheme` explicitly rather than calling `ColorScheme.fromSeed` (`learning_tracker/lib/core/theme/app_theme.dart:73-77`, `:112-140`; `learning_tracker/lib/core/theme/app_palette.dart:69-87`).
- The `ColorScheme` fields map to these brightness-aware tokens: primary=`brandBlue` (or caller accent), primaryContainer=`brandBlueSoft`, secondary=`brandCoral`, secondaryContainer=`brandCoralSoft`, tertiary=`brandGold`, tertiaryContainer=`brandGoldSoft`, error=`brandError`, errorContainer=`brandErrorSoft`, surface=`brandCreamCard`, surface containers=`brandCreamCard`/`brandCream`/`brandCreamSoft`, onSurface=`brandInk`, onSurfaceVariant=`brandInkMuted`, outlines=`brandOutline`/`brandOutlineMuted`; on-fill roles use a contrast comparison between white and `#0B0F1A` (`learning_tracker/lib/core/theme/app_theme.dart:87-140`).
- Core light/dark token hex pairs (light / dark):
  - Blue: `brandBlue #1442B8 / #7CA0FF`; bright `#2B5FD9 / #A3BEFF`; deep `#0E3392 / #B9C9FF`; soft `#E4EBFA / #16233F` (`learning_tracker/lib/core/theme/app_palette.dart:69-87`).
  - Coral: `#E05A30 / #FF8A5C`; soft `#FDE9E2 / #2E1C14`; deep `#B03F1D / #FFB294` (`app_palette.dart:89-99`).
  - Warning: `#C77A12 / #E0A54A`; soft `#FBF0DC / #2E220E`; deep `#8A5306 / #F0C883` (`app_palette.dart:101-111`).
  - Success/gold: `#4F7A28 / #8FBF5F`; soft `#E3EDD3 / #1B2A12`; deep `#3A5C1B / #B4D98C` (`app_palette.dart:113-123`).
  - Canvas/card/recessed surfaces: `brandCream #F7F8FB / #0B0F1A`; card `#FFFFFF / #151A26`; soft `#EFF2F7 / #1E2532` (`app_palette.dart:125-135`).
  - Outline/ink: outline `#D4DCE8 / #263041`; muted outline `#C7D0DE / #36425A`; ink `#101828 / #EAEEF5`; body ink `#2B3444 / #C3CBD8`; muted ink `#5A6474 / #98A2B3`; soft ink `#6A7484 / #828D9E` (`app_palette.dart:137-159`).
  - Error/error-soft: `#C0362C / #F0857B`; `#FBE9E7 / #2E1512` (`app_palette.dart:161-167`).
- Curriculum identity colors also have light/dark pairs: Mishna `#277B3C/#62D186`, Bavli `#1B6B5A/#4FC4A8`, Yerushalmi `#1A57C2/#7FA8FF`, Mishna Berurah `#4F7A28/#8FBF5F`, Chumash `#8A5E1D/#D9A54B`, Nach `#0B7D79/#3FD3CE` (`learning_tracker/lib/core/theme/app_palette.dart:169-190`). Additional palette-specific semantic, chart, status, track, profile, and feature tokens are explicit in `app_palette.dart`; core named additions include dark-safe fill variants at `:1480-1525` and profile tokens at `:1527-1555`.
- Theme-extension API is `AppPalette extends ThemeExtension<AppPalette>`, resolves by brightness, and `context.colors` exposes it to widgets; the extension is registered on both `ThemeData`s (`learning_tracker/lib/core/theme/app_palette.dart:23-63`; `learning_tracker/lib/core/theme/app_theme.dart:108-112`).
- Other explicit theme styling: scaffold/canvas use `brandCream`; icons use muted ink; AppBar is cream, centered title, 0 elevation; cards are card-surface, 0 elevation, 18dp radius, 1dp outline, zero margin (`app_theme.dart:142-168`). Buttons are elevation 0, pill radius 30, with 24x16dp filled/elevated padding, and text buttons use radius 8 (`app_theme.dart:170-224`). Inputs are filled, 12dp radius, 2dp focused outline, 16dp horizontal/vertical content padding (`app_theme.dart:225-249`). Navigation bar and bottom-nav elevation are 0; chip radius 20; checkbox radius 4; dialog radius 16; modal sheet top radius 24; snack bar radius 12; tooltip radius 8 (`app_theme.dart:250-385`).
- Shadows are set only as `ColorScheme.shadow` black at alpha 0.07 light / 0.5 dark; bottom-sheet modal barrier is black alpha 0.45 light / 0.62 dark. Snack bars float (`app_theme.dart:138-140`, `:358-385`). A shared `AppDialog` surface independently uses radius 28 and elevation 0 (`learning_tracker/lib/core/widgets/app_dialog.dart:134-165`).

### Typography, spacing, shapes

- Material text theme is based on Google Fonts Plus Jakarta Sans. Display/headline/titleLarge are brand ink and w700; titleMedium/titleSmall/labelLarge use primary ink and w600; bodyLarge/bodyMedium use body ink; bodySmall/labelMedium/labelSmall use muted ink (`learning_tracker/lib/core/theme/app_theme.dart:29-60`). Flutter's inherited size scale is retained by copying the font theme styles rather than assigning replacement sizes there (`app_theme.dart:29-60`).
- App bar title is Plus Jakarta Sans 18sp/w700 with 0.3 letter spacing; buttons are 15sp/w600; nav labels 12sp; chips 13sp; tooltips 12sp (`learning_tracker/lib/core/theme/app_theme.dart:150-158`, `:180-202`, `:269-279`, `:290-307`, `:380-389`).
- `AppTextStyles` provides Plus Jakarta Sans English/base styles and a bundled `Noto Sans Hebrew` family (`learning_tracker/lib/core/theme/text_styles.dart:12-25`). Its named headline sizes are 32/28/24sp; titleLarge 22sp; further styles are defined in the same file (`text_styles.dart:27-51`).
- Full named `AppTextStyles` scale: headlines 32/28/24sp bold/bold/w600; titles 22/18/16sp w600; body 16/14/12sp normal; labels 14/12/11sp w500; line heights are 1.2–1.5 as declared. Hebrew headline/title variants retain those styles and switch family; Hebrew body variants are 18/16/14sp with 1.6 height (`learning_tracker/lib/core/theme/text_styles.dart:27-138`). The Material `TextTheme` builder separately inherits Flutter's standard type sizes and applies role colors/weights (`app_theme.dart:29-60`).
- No shared named spacing scale was found in `core/theme` or `core/constants`; layout uses local `EdgeInsets`/`SizedBox` values. Theme-level common padding values are button 24x16dp, text button 16x8dp, outlined button 24x14dp, input 16x16dp (`learning_tracker/lib/core/theme/app_theme.dart:170-249`). Shared dialog uses 24dp horizontal inset, 24dp vertical breathing room, max width 480dp (`learning_tracker/lib/core/widgets/app_dialog.dart:27-35`).

### Complete AppPalette color-token ledger

Each getter is listed so the full explicit palette can be traced, including feature/chart tokens beyond the core theme colors above. Paired values are in light / dark order; computed getters cite their expression.

| Token | Explicit color value(s) | Source |
|---|---|---|
| `brandBlue` | 0xFF7CA0FF / 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:70-71` |
| `brandBlueBright` | 0xFFA3BEFF / 0xFF2B5FD9 | `learning_tracker/lib/core/theme/app_palette.dart:74-75` |
| `brandBlueDeep` | 0xFFB9C9FF / 0xFF0E3392 | `learning_tracker/lib/core/theme/app_palette.dart:82-83` |
| `brandBlueSoft` | 0xFF16233F / 0xFFE4EBFA | `learning_tracker/lib/core/theme/app_palette.dart:86-87` |
| `brandCoral` | 0xFFFF8A5C / 0xFFE05A30 | `learning_tracker/lib/core/theme/app_palette.dart:90-91` |
| `brandCoralSoft` | 0xFF2E1C14 / 0xFFFDE9E2 | `learning_tracker/lib/core/theme/app_palette.dart:94-95` |
| `brandCoralDeep` | 0xFFFFB294 / 0xFFB03F1D | `learning_tracker/lib/core/theme/app_palette.dart:98-99` |
| `brandWarning` | 0xFFE0A54A / 0xFFC77A12 | `learning_tracker/lib/core/theme/app_palette.dart:102-103` |
| `brandWarningSoft` | 0xFF2E220E / 0xFFFBF0DC | `learning_tracker/lib/core/theme/app_palette.dart:106-107` |
| `brandWarningDeep` | 0xFFF0C883 / 0xFF8A5306 | `learning_tracker/lib/core/theme/app_palette.dart:110-111` |
| `brandGold` | 0xFF8FBF5F / 0xFF4F7A28 | `learning_tracker/lib/core/theme/app_palette.dart:114-115` |
| `brandGoldSoft` | 0xFF1B2A12 / 0xFFE3EDD3 | `learning_tracker/lib/core/theme/app_palette.dart:118-119` |
| `brandGoldDeep` | 0xFFB4D98C / 0xFF3A5C1B | `learning_tracker/lib/core/theme/app_palette.dart:122-123` |
| `brandCream` | 0xFF0B0F1A / 0xFFF7F8FB | `learning_tracker/lib/core/theme/app_palette.dart:126-127` |
| `brandCreamCard` | 0xFF151A26 / 0xFFFFFFFF | `learning_tracker/lib/core/theme/app_palette.dart:130-131` |
| `brandCreamSoft` | 0xFF1E2532 / 0xFFEFF2F7 | `learning_tracker/lib/core/theme/app_palette.dart:134-135` |
| `brandOutline` | 0xFF263041 / 0xFFD4DCE8 | `learning_tracker/lib/core/theme/app_palette.dart:138-139` |
| `brandOutlineMuted` | 0xFF36425A / 0xFFC7D0DE | `learning_tracker/lib/core/theme/app_palette.dart:142-143` |
| `brandInk` | 0xFFEAEEF5 / 0xFF101828 | `learning_tracker/lib/core/theme/app_palette.dart:146-147` |
| `brandInk2` | 0xFFC3CBD8 / 0xFF2B3444 | `learning_tracker/lib/core/theme/app_palette.dart:150-151` |
| `brandInkMuted` | 0xFF98A2B3 / 0xFF5A6474 | `learning_tracker/lib/core/theme/app_palette.dart:154-155` |
| `brandInkSoft` | 0xFF828D9E / 0xFF6A7484 | `learning_tracker/lib/core/theme/app_palette.dart:158-159` |
| `brandError` | 0xFFF0857B / 0xFFC0362C | `learning_tracker/lib/core/theme/app_palette.dart:162-163` |
| `brandErrorSoft` | 0xFF2E1512 / 0xFFFBE9E7 | `learning_tracker/lib/core/theme/app_palette.dart:166-167` |
| `curriculumMishna` | 0xFF62D186 / 0xFF277B3C | `learning_tracker/lib/core/theme/app_palette.dart:173-174` |
| `curriculumBavli` | 0xFF4FC4A8 / 0xFF1B6B5A | `learning_tracker/lib/core/theme/app_palette.dart:176-177` |
| `curriculumYerushalmi` | 0xFF7FA8FF / 0xFF1A57C2 | `learning_tracker/lib/core/theme/app_palette.dart:179-180` |
| `curriculumMishnaBerurah` | 0xFF8FBF5F / 0xFF4F7A28 | `learning_tracker/lib/core/theme/app_palette.dart:182-183` |
| `curriculumChumash` | 0xFFD9A54B / 0xFF8A5E1D | `learning_tracker/lib/core/theme/app_palette.dart:185-186` |
| `curriculumNach` | 0xFF3FD3CE / 0xFF0B7D79 | `learning_tracker/lib/core/theme/app_palette.dart:188-189` |
| `curriculumMussar` | 0xFFAF8CFA / 0xFF6D28D9 | `learning_tracker/lib/core/theme/app_palette.dart:191-192` |
| `statusError` | 0xFFDE8686 / 0xFFC92A2A | `learning_tracker/lib/core/theme/app_palette.dart:201-202` |
| `statusErrorSoft` | 0xFF331318 / 0xFFFDE7EA | `learning_tracker/lib/core/theme/app_palette.dart:205-206` |
| `statusDanger` | 0xFFE97B7B / 0xFFF26666 | `learning_tracker/lib/core/theme/app_palette.dart:209-210` |
| `statusWarning` | 0xFFE6B96A / 0xFFE9A42A | `learning_tracker/lib/core/theme/app_palette.dart:213-214` |
| `statusWarningSoft` | 0xFF332B13 / 0xFFFFF2CF | `learning_tracker/lib/core/theme/app_palette.dart:217-218` |
| `statusSuccess` | 0xFF72DE9A / 0xFF22C55E | `learning_tracker/lib/core/theme/app_palette.dart:221-222` |
| `statusSuccessMuted` | 0xFF72DEA4 / 0xFF3BDD87 | `learning_tracker/lib/core/theme/app_palette.dart:225-226` |
| `statusSuccessDeep` | 0xFF93D196 / 0xFF2E7D32 | `learning_tracker/lib/core/theme/app_palette.dart:229-230` |
| `surfaceF5` | 0xFF131C33 / 0xFFF5F7FC | `learning_tracker/lib/core/theme/app_palette.dart:233-234` |
| `surfaceF3` | 0xFF1E2532 / 0xFFF3F4F8 | `learning_tracker/lib/core/theme/app_palette.dart:237-238` |
| `surfaceF4` | 0xFF1E2532 / 0xFFF4F5F8 | `learning_tracker/lib/core/theme/app_palette.dart:241-242` |
| `surfaceF4b` | 0xFF131C33 / 0xFFF4F6FB | `learning_tracker/lib/core/theme/app_palette.dart:245-246` |
| `surfaceE9` | 0xFF263041 / 0xFFE9ECF2 | `learning_tracker/lib/core/theme/app_palette.dart:250-251` |
| `surfaceBlueNeutral` | 0xFF161D30 / 0xFFF0F2F8 | `learning_tracker/lib/core/theme/app_palette.dart:254-255` |
| `surfaceBlueLight` | 0xFF131833 / 0xFFE5E9FF | `learning_tracker/lib/core/theme/app_palette.dart:258-259` |
| `surfaceGreyBlue` | 0xFF181E2F / 0xFFE2E6F0 | `learning_tracker/lib/core/theme/app_palette.dart:262-263` |
| `blueNavy` | 0xFF02113B / 0xFF03174C | `learning_tracker/lib/core/theme/app_palette.dart:266-267` |
| `blueDeepNavy` | 0xFF071843 / 0xFF0A2056 | `learning_tracker/lib/core/theme/app_palette.dart:270-271` |
| `blueMedium` | 0xFF163797 / 0xFF1C47C4 | `learning_tracker/lib/core/theme/app_palette.dart:282-283` |
| `blueLight` | 0xFF112C81 / 0xFF1639A8 | `learning_tracker/lib/core/theme/app_palette.dart:289-290` |
| `blueMid` | 0xFF0E2F86 / 0xFF123DAE | `learning_tracker/lib/core/theme/app_palette.dart:299-300` |
| `chartLimudBlue` | 0xFFAFBFE8 / 0xFF123DAE | `learning_tracker/lib/core/theme/app_palette.dart:310-311` |
| `chazaraSelectedGradientStart` | 0xFF0E3392 | `learning_tracker/lib/core/theme/app_palette.dart:330-330` |
| `chazaraSelectedGradientEnd` | 0xFF2B5FD9 | `learning_tracker/lib/core/theme/app_palette.dart:335-335` |
| `goldTrophy` | 0xFF332A13 / 0xFFFFC94A | `learning_tracker/lib/core/theme/app_palette.dart:343-344` |
| `goldOnColouredSurface` | 0xFFFFC94A | `learning_tracker/lib/core/theme/app_palette.dart:361-361` |
| `goldAmber` | 0xFFE6B96A / 0xFFE9A42A | `learning_tracker/lib/core/theme/app_palette.dart:364-365` |
| `goldDark` | 0xFFE8D2AF / 0xFF7D5411 | `learning_tracker/lib/core/theme/app_palette.dart:368-369` |
| `peachTint` | 0xFF332513 / 0xFFF9E4C8 | `learning_tracker/lib/core/theme/app_palette.dart:372-373` |
| `peachMid` | 0xFF332613 / 0xFFF3D4A5 | `learning_tracker/lib/core/theme/app_palette.dart:376-377` |
| `peachDark` | 0xFFE1D2B6 / 0xFF594624 | `learning_tracker/lib/core/theme/app_palette.dart:380-381` |
| `warnYellow` | 0xFF332B13 / 0xFFFFF2CF | `learning_tracker/lib/core/theme/app_palette.dart:384-385` |
| `chartBlue` | 0xFF699DE6 / 0xFF4D96FF | `learning_tracker/lib/core/theme/app_palette.dart:388-389` |
| `chartTeal` | 0xFF7BDFE9 / 0xFF0097A7 | `learning_tracker/lib/core/theme/app_palette.dart:392-393` |
| `chartGreen` | 0xFF83CC8C / 0xFF6BCB77 | `learning_tracker/lib/core/theme/app_palette.dart:396-397` |
| `chartAmber` | 0xFF332913 / 0xFFF8C146 | `learning_tracker/lib/core/theme/app_palette.dart:400-401` |
| `chartRed` | 0xFFD58F99 / 0xFFB43A4A | `learning_tracker/lib/core/theme/app_palette.dart:404-405` |
| `chartBarBg` | 0xFF2A3346 / 0xFF404060 | `learning_tracker/lib/core/theme/app_palette.dart:408-409` |
| `chartBarFillMuted` | 0xFF36425A / 0xFF9E9E9E | `learning_tracker/lib/core/theme/app_palette.dart:412-413` |
| `streakActive` | 0xFF4ADE80 / 0xFF69F0AE | `learning_tracker/lib/core/theme/app_palette.dart:416-417` |
| `streakEmpty` | 0xFF4A5568 / 0xFF90A4AE | `learning_tracker/lib/core/theme/app_palette.dart:420-421` |
| `inkDeepDark` | 0xFFEAEEF5 / 0xFF1A1A1A | `learning_tracker/lib/core/theme/app_palette.dart:424-425` |
| `inkSlate` | 0xFFEAEEF5 / 0xFF4A5568 | `learning_tracker/lib/core/theme/app_palette.dart:428-429` |
| `inkMidGrey` | 0xFF98A2B3 / 0xFF8E97A6 | `learning_tracker/lib/core/theme/app_palette.dart:432-433` |
| `iconBlueGrey` | 0xFF98A2B3 / 0xFF78909C | `learning_tracker/lib/core/theme/app_palette.dart:436-437` |
| `accentPurpleDeep` | 0xFFC2B0E7 / 0xFF4A2A8A | `learning_tracker/lib/core/theme/app_palette.dart:440-441` |
| `accentTealGreen` | 0xFF88DCD3 / 0xFF1D7D73 | `learning_tracker/lib/core/theme/app_palette.dart:444-445` |
| `accentTealSoft` | 0xFF132833 / 0xFFE0F4FF | `learning_tracker/lib/core/theme/app_palette.dart:448-449` |
| `accentCoral` | 0xFFE66969 / 0xFFF86B6B | `learning_tracker/lib/core/theme/app_palette.dart:452-453` |
| `accentBurntOrange` | 0xFFE9A27B / 0xFFC24400 | `learning_tracker/lib/core/theme/app_palette.dart:456-457` |
| `scrimDark` | 0x99000000 / 0x40000000 | `learning_tracker/lib/core/theme/app_palette.dart:460-461` |
| `scrimLight` | 0x33FFFFFF / 0x33FFFFFF | `learning_tracker/lib/core/theme/app_palette.dart:464-465` |
| `statusSuccessSoftBg` | 0xFF173017 / 0xFFEAF5EA | `learning_tracker/lib/core/theme/app_palette.dart:469-470` |
| `statusSuccessSoftText` | 0xFF9ACA9A / 0xFF3A7C3A | `learning_tracker/lib/core/theme/app_palette.dart:473-474` |
| `statusWarningSoftText` | 0xFFE9C77B / 0xFF916400 | `learning_tracker/lib/core/theme/app_palette.dart:478-479` |
| `statusErrorCardBg` | 0xFF331318 / 0xFFFFEBEE | `learning_tracker/lib/core/theme/app_palette.dart:482-483` |
| `statusErrorCardText` | 0xFFE6807E / 0xFFD51F1B | `learning_tracker/lib/core/theme/app_palette.dart:486-487` |
| `statusActiveBadge` | 0xFF96CE99 / 0xFF43A047 | `learning_tracker/lib/core/theme/app_palette.dart:490-491` |
| `statusPendingBadge` | 0xFFE6A969 / 0xFFF57C00 | `learning_tracker/lib/core/theme/app_palette.dart:494-495` |
| `statusSuccessSnackbar` | 0xFF95CF97 / 0xFF388E3C | `learning_tracker/lib/core/theme/app_palette.dart:498-499` |
| `tutorPinBadgeBg` | 0xFF1B1333 / 0xFFE8E0FF | `learning_tracker/lib/core/theme/app_palette.dart:502-503` |
| `tutorPinBadgeIcon` | 0xFFC9B5E2 / 0xFF6B3FA0 | `learning_tracker/lib/core/theme/app_palette.dart:506-507` |
| `tutorPinKeyDisabled` | 0xFF3A4459 / 0xFFC9D0DA | `learning_tracker/lib/core/theme/app_palette.dart:510-511` |
| `auditActionConfig` | 0xFF7DB5E7 / 0xFF1E88E5 | `learning_tracker/lib/core/theme/app_palette.dart:514-515` |
| `auditActionBulkPrior` | 0xFF96CE99 / 0xFF43A047 | `learning_tracker/lib/core/theme/app_palette.dart:518-519` |
| `auditActionReset` | 0xFFE6A969 / 0xFFF57C00 | `learning_tracker/lib/core/theme/app_palette.dart:522-523` |
| `auditActionBookmark` | 0xFFDCAFE8 / 0xFF8E24AA | `learning_tracker/lib/core/theme/app_palette.dart:526-527` |
| `auditActionProfileEdited` | 0xFF7BE9DE / 0xFF00897B | `learning_tracker/lib/core/theme/app_palette.dart:530-531` |
| `auditActionGoalChanged` | 0xFFB2B9E5 / 0xFF3949AB | `learning_tracker/lib/core/theme/app_palette.dart:534-535` |
| `auditActionStageChanged` | 0xFF7BDFE9 / 0xFF0097A7 | `learning_tracker/lib/core/theme/app_palette.dart:538-539` |
| `auditActionRewardChanged` | 0xFFE6B869 / 0xFFFFA000 | `learning_tracker/lib/core/theme/app_palette.dart:542-543` |
| `auditActionStudyDayChanged` | 0xFFE9957B / 0xFFF4511E | `learning_tracker/lib/core/theme/app_palette.dart:546-547` |
| `tutorModeAccent` | 0xFFE9B67B / 0xFFD97706 | `learning_tracker/lib/core/theme/app_palette.dart:552-553` |
| `childViewAccent` | 0xFF7BE9CA / 0xFF047857 | `learning_tracker/lib/core/theme/app_palette.dart:558-559` |
| `switcherBarBackground` | 0xFF131A33 / 0xFFF1F3FA | `learning_tracker/lib/core/theme/app_palette.dart:566-567` |
| `switcherBarBorder` | 0xFF131C33 / 0xFFD7DEF0 | `learning_tracker/lib/core/theme/app_palette.dart:570-571` |
| `navSelectedBlue` | 0xFF002B81 / 0xFF0038A8 | `learning_tracker/lib/core/theme/app_palette.dart:581-582` |
| `navBarShadow` | 0x1C000000 / 0x140038A8 | `learning_tracker/lib/core/theme/app_palette.dart:585-586` |
| `navItemSelectedShadow` | 0x47000000 / 0x330038A8 | `learning_tracker/lib/core/theme/app_palette.dart:589-590` |
| `navUnselectedText` | 0xFF98A2B3 / 0xFF708090 | `learning_tracker/lib/core/theme/app_palette.dart:593-594` |
| `introNavy` | 0xFF142A80 / 0xFF1A36A5 | `learning_tracker/lib/core/theme/app_palette.dart:598-599` |
| `introCtaLabel` | 0xFFFFFFFF | `learning_tracker/lib/core/theme/app_palette.dart:614-614` |
| `introPeach` | 0xFF331C13 / 0xFFFFD8C8 | `learning_tracker/lib/core/theme/app_palette.dart:617-618` |
| `introPillBlue` | 0xFF131E33 / 0xFFC8D8F8 | `learning_tracker/lib/core/theme/app_palette.dart:621-622` |
| `introProgressTrackBg` | 0xFF263041 / 0xFFE2E5EB | `learning_tracker/lib/core/theme/app_palette.dart:625-626` |
| `introProgressFillGreen` | 0xFF70DFB5 / 0xFF1DB97D | `learning_tracker/lib/core/theme/app_palette.dart:630-631` |
| `introMysteryBorder` | 0xFFCCB384 / 0xFFC9A86A | `learning_tracker/lib/core/theme/app_palette.dart:634-635` |
| `introBadgeBg` | 0xFF131933 / 0xFFE8ECFF | `learning_tracker/lib/core/theme/app_palette.dart:639-640` |
| `introMysteryBg` | 0xFF332713 / 0xFFFFF3E0 | `learning_tracker/lib/core/theme/app_palette.dart:643-644` |
| `introMysteryText` | 0xFFDFD1B8 / 0xFF5C4A2A | `learning_tracker/lib/core/theme/app_palette.dart:647-648` |
| `introMysteryIcon` | 0xFFE8D2AF / 0xFF6B4E1E | `learning_tracker/lib/core/theme/app_palette.dart:651-652` |
| `introCardShadow` | 0x40000000 / 0x2E000000 | `learning_tracker/lib/core/theme/app_palette.dart:655-656` |
| `introScholarTrackBg` | 0xFF263041 / 0xFFE8EAEF | `learning_tracker/lib/core/theme/app_palette.dart:659-660` |
| `introIndicatorInactive` | 0xFF263041 / 0xFFDCE0EA | `learning_tracker/lib/core/theme/app_palette.dart:663-664` |
| `introWindowDotBlue` | 0xFF6CC0E4 / 0xFF5BC0EB | `learning_tracker/lib/core/theme/app_palette.dart:668-669` |
| `introDailyRowPillBg` | 0xFF1E2532 / 0xFFF0F1F4 | `learning_tracker/lib/core/theme/app_palette.dart:673-674` |
| `introDailyRowTrackFilled` | 0xFF263041 / 0xFFDCDFE5 | `learning_tracker/lib/core/theme/app_palette.dart:678-679` |
| `introDailyCheckboxBorder` | 0xFF1E2228 / 0xFFC9CED6 | `learning_tracker/lib/core/theme/app_palette.dart:683-684` |
| `introDailyRowTrackEmpty` | 0xFF263041 / 0xFFE5E7EC | `learning_tracker/lib/core/theme/app_palette.dart:688-689` |
| `notifReminderIconTint` | 0xFFAFBDE8 / 0xFF2A4BB3 | `learning_tracker/lib/core/theme/app_palette.dart:692-693` |
| `notifReminderIconBg` | 0xFF131733 / 0xFFE8EBFF | `learning_tracker/lib/core/theme/app_palette.dart:697-698` |
| `notifStreakIconTint` | 0xFFE18389 / 0xFFD32430 | `learning_tracker/lib/core/theme/app_palette.dart:701-702` |
| `notifStreakIconBg` | 0xFF331319 / 0xFFFDECEF | `learning_tracker/lib/core/theme/app_palette.dart:705-706` |
| `notifRewardIconTint` | 0xFFDBBA89 / 0xFF936623 | `learning_tracker/lib/core/theme/app_palette.dart:709-710` |
| `notifRewardIconBg` | 0xFF332813 / 0xFFFDF2DE | `learning_tracker/lib/core/theme/app_palette.dart:714-715` |
| `notifCardShadow` | 0x19000000 / 0x12061D56 | `learning_tracker/lib/core/theme/app_palette.dart:718-719` |
| `notifTitleText` | 0xFFB9C2DE / 0xFF151B2D | `learning_tracker/lib/core/theme/app_palette.dart:722-723` |
| `notifSubtitleText` | 0xFF98A2B3 / 0xFF7A8293 | `learning_tracker/lib/core/theme/app_palette.dart:727-728` |
| `notifTimeTextEnabled` | 0xFFB6C0E1 / 0xFF1A2340 | `learning_tracker/lib/core/theme/app_palette.dart:731-732` |
| `notifTimeTextDisabled` | 0xFF98A2B3 / 0xFF9CA3B4 | `learning_tracker/lib/core/theme/app_palette.dart:735-736` |
| `notifHotStreakBadge` | 0xFFE66975 / 0xFFFF6A78 | `learning_tracker/lib/core/theme/app_palette.dart:739-740` |
| `notifDeviceToggleActiveTrack` | 0xFF0E2E80 / 0xFF123CA5 | `learning_tracker/lib/core/theme/app_palette.dart:743-744` |
| `notifDeviceToggleInactiveTrack` | 0xFF263041 / 0xFFE0E4ED | `learning_tracker/lib/core/theme/app_palette.dart:747-748` |
| `gamifChildRewardsCardBlueTop` | 0xFF173FA5 / 0xFF1E52D4 | `learning_tracker/lib/core/theme/app_palette.dart:750-751` |
| `gamifSoftBlueCardBg` | 0xFF132133 / 0xFFEEF3FA | `learning_tracker/lib/core/theme/app_palette.dart:753-754` |
| `gamifInkCharcoal` | 0xFFEAEEF5 / 0xFF37474F | `learning_tracker/lib/core/theme/app_palette.dart:756-757` |
| `gamifFieldFillLight` | 0xFF18202E / 0xFFF2F4F8 | `learning_tracker/lib/core/theme/app_palette.dart:759-760` |
| `gamifMutedLabelGrey` | 0xFFACB0B8 / 0xFF6B7280 | `learning_tracker/lib/core/theme/app_palette.dart:762-763` |
| `gamifTierLockedIconGrey` | 0xFF98A2B3 / 0xFFB0BEC5 | `learning_tracker/lib/core/theme/app_palette.dart:765-766` |
| `gamifLegendGradientEnd` | 0xFF390F6D / 0xFF4A148C | `learning_tracker/lib/core/theme/app_palette.dart:768-769` |
| `gamifInkSlateDark` | 0xFFEAEEF5 / 0xFF455A64 | `learning_tracker/lib/core/theme/app_palette.dart:771-772` |
| `gamifPointConfigScreenBg` | 0xFF151A26 / 0xFFF8F9FB | `learning_tracker/lib/core/theme/app_palette.dart:774-775` |
| `gamifPointConfigOrangeAccent` | 0xFFE6B769 / 0xFFF5A623 | `learning_tracker/lib/core/theme/app_palette.dart:777-778` |
| `gamifPointConfigActiveBadgeBg` | 0xFF332013 / 0xFFFFE4D1 | `learning_tracker/lib/core/theme/app_palette.dart:780-781` |
| `gamifPointConfigActiveBadgeInk` | 0xFFDAC6BD / 0xFF5C4033 | `learning_tracker/lib/core/theme/app_palette.dart:783-784` |
| `gamifPointConfigHebrewSubtitleBlue` | 0xFF7BAAD5 / 0xFF5B9BD5 | `learning_tracker/lib/core/theme/app_palette.dart:786-787` |
| `gamifPointConfigHeroBlueTop` | 0xFF002379 / 0xFF002D9C | `learning_tracker/lib/core/theme/app_palette.dart:789-790` |
| `gamifPointConfigHeroBlueBottom` | 0xFF001855 / 0xFF001F6E | `learning_tracker/lib/core/theme/app_palette.dart:792-793` |
| `gamifPointConfigChipUnselectedBg` | 0xFF263041 / 0xFFE8EBF0 | `learning_tracker/lib/core/theme/app_palette.dart:795-796` |
| `gamifCardShadowNavySoft` | 0x19000000 / 0x1200218D | `learning_tracker/lib/core/theme/app_palette.dart:798-799` |
| `gamifLegendGradientStart` | 0xFF141B62 / 0xFF1A237E | `learning_tracker/lib/core/theme/app_palette.dart:801-802` |
| `gamifLegendCardShadow` | 0x5F000000 / 0x441A237E | `learning_tracker/lib/core/theme/app_palette.dart:804-805` |
| `gamifPartyColorCoral` | 0xFFE66969 / 0xFFFF6B6B | `learning_tracker/lib/core/theme/app_palette.dart:807-808` |
| `gamifPartyColorYellow` | 0xFF332D13 / 0xFFFFD93D | `learning_tracker/lib/core/theme/app_palette.dart:810-811` |
| `gamifPartyColorPink` | 0xFFE669D7 / 0xFFFF9FF3 | `learning_tracker/lib/core/theme/app_palette.dart:813-814` |
| `gamifPartyColorOrange` | 0xFFE6BA69 / 0xFFFFA502 | `learning_tracker/lib/core/theme/app_palette.dart:816-817` |
| `gamifPartyColorPurple` | 0xFFC2AFE8 / 0xFF5F27CD | `learning_tracker/lib/core/theme/app_palette.dart:819-820` |
| `gamifUnlockCardGradientCream` | 0xFF332813 / 0xFFFFF4E0 | `learning_tracker/lib/core/theme/app_palette.dart:822-823` |
| `gamifUnlockCardGradientPink` | 0xFF331324 / 0xFFFFE0F0 | `learning_tracker/lib/core/theme/app_palette.dart:825-826` |
| `gamifUnlockCardShadow` | 0x6B000000 / 0x4D0038A8 | `learning_tracker/lib/core/theme/app_palette.dart:828-829` |
| `gamifLockedShellInkDeepest` | 0xFFEAEEF5 / 0xFF263238 | `learning_tracker/lib/core/theme/app_palette.dart:831-832` |
| `gamifProTipCardBg` | 0xFF332713 / 0xFFFFEFD5 | `learning_tracker/lib/core/theme/app_palette.dart:834-835` |
| `gamifProTipBorder` | 0xFF332613 / 0xFFFFCC80 | `learning_tracker/lib/core/theme/app_palette.dart:837-838` |
| `gamifProTipShadow` | 0x1C000000 / 0x14000000 | `learning_tracker/lib/core/theme/app_palette.dart:840-841` |
| `gamifProTipTitleText` | 0xFFEAEEF5 / 0xFF212121 | `learning_tracker/lib/core/theme/app_palette.dart:843-844` |
| `gamifTrackFilterChipUnselected` | 0xFF263041 / 0xFFE0E4E8 | `learning_tracker/lib/core/theme/app_palette.dart:846-847` |
| `gamifTrackFilterChipShadow` | 0x2F000000 / 0x220038A8 | `learning_tracker/lib/core/theme/app_palette.dart:849-850` |
| `gamifTierBronzeCardBg` | 0xFF332513 / 0xFFF5E6D3 | `learning_tracker/lib/core/theme/app_palette.dart:852-853` |
| `gamifTierBronzeBorder` | 0xFF332214 / 0xFFE8D5C4 | `learning_tracker/lib/core/theme/app_palette.dart:855-856` |
| `gamifTierBronzeIconAccent` | 0xFFBEACA6 / 0xFF8D6E63 | `learning_tracker/lib/core/theme/app_palette.dart:858-859` |
| `gamifTierBronzeDeepAccent` | 0xFFD8C5BF / 0xFF6D4C41 | `learning_tracker/lib/core/theme/app_palette.dart:861-862` |
| `gamifTierBronzeTitle` | 0xFFD9C3BE / 0xFF4E342E | `learning_tracker/lib/core/theme/app_palette.dart:864-865` |
| `gamifTierBronzeSoftAccent` | 0xFF332613 / 0xFFFFE0B2 | `learning_tracker/lib/core/theme/app_palette.dart:867-868` |
| `gamifTierBronzeTagFg` | 0xFFE9957B / 0xFFBF360C | `learning_tracker/lib/core/theme/app_palette.dart:870-871` |
| `gamifTierBronzeLockIcon` | 0xFFD9C5BE / 0xFF5D4037 | `learning_tracker/lib/core/theme/app_palette.dart:873-874` |
| `gamifTierSilverBorder` | 0xFF1E2532 / 0xFFECEFF1 | `learning_tracker/lib/core/theme/app_palette.dart:876-877` |
| `gamifTierSilverBarBg` | 0xFF263041 / 0xFFE8ECEF | `learning_tracker/lib/core/theme/app_palette.dart:879-880` |
| `gamifTierSilverBarFill` | 0xFFA6B7BE / 0xFF546E7A | `learning_tracker/lib/core/theme/app_palette.dart:882-883` |
| `gamifTierSilverTagBg` | 0xFF1E2529 / 0xFFCFD8DC | `learning_tracker/lib/core/theme/app_palette.dart:885-886` |
| `gamifTierSilverLockIcon` | 0xFFA6B6BE / 0xFF607D8B | `learning_tracker/lib/core/theme/app_palette.dart:888-889` |
| `gamifTierGoldCardBg` | 0xFF332C13 / 0xFFFFF9E6 | `learning_tracker/lib/core/theme/app_palette.dart:891-892` |
| `gamifTierGoldBorder` | 0xFF332B13 / 0xFFFFECB3 | `learning_tracker/lib/core/theme/app_palette.dart:894-895` |
| `gamifTierGoldIconBg` | 0xFF332C13 / 0xFFFFC400 | `learning_tracker/lib/core/theme/app_palette.dart:897-898` |
| `gamifTierGoldTitle` | 0xFFE6A469 / 0xFFB25707 | `learning_tracker/lib/core/theme/app_palette.dart:900-901` |
| `gamifTierGoldMutedIcon` | 0xFFE6C169 / 0xFFFFB300 | `learning_tracker/lib/core/theme/app_palette.dart:903-904` |
| `gamifTierGoldBarBg` | 0xFF332B13 / 0xFFFFE082 | `learning_tracker/lib/core/theme/app_palette.dart:906-907` |
| `gamifTierGoldBarFill` | 0xFFE6AF69 / 0xFFFF8F00 | `learning_tracker/lib/core/theme/app_palette.dart:909-910` |
| `gamifTierGoldTagBg` | 0xFF332D13 / 0xFFFFF3C4 | `learning_tracker/lib/core/theme/app_palette.dart:912-913` |
| `gamifTierGoldLockIcon` | 0xFFE6B769 / 0xFFF9A825 | `learning_tracker/lib/core/theme/app_palette.dart:915-916` |
| `gamifTierPlatinumCardBg` | 0xFF132033 / 0xFFFAFCFF | `learning_tracker/lib/core/theme/app_palette.dart:918-919` |
| `gamifTierPlatinumSoftAccent` | 0xFF132533 / 0xFFBBDEFB | `learning_tracker/lib/core/theme/app_palette.dart:921-922` |
| `gamifTierPlatinumIconBg` | 0xFF132633 / 0xFFE3F2FD | `learning_tracker/lib/core/theme/app_palette.dart:924-925` |
| `gamifTierPlatinumIconFg` | 0xFF69AEE6 / 0xFF0A6FC1 | `learning_tracker/lib/core/theme/app_palette.dart:927-928` |
| `gamifTierPlatinumMidAccent` | 0xFF69AFE6 / 0xFF64B5F6 | `learning_tracker/lib/core/theme/app_palette.dart:930-931` |
| `gamifTierPlatinumTitle` | 0xFF7CAFE8 / 0xFF1565C0 | `learning_tracker/lib/core/theme/app_palette.dart:933-934` |
| `gamifTierPlatinumBarFill` | 0xFF7BB8E9 / 0xFF2196F3 | `learning_tracker/lib/core/theme/app_palette.dart:936-937` |
| `gamifTierPlatinumTagBg` | 0xFF132933 / 0xFFE1F5FE | `learning_tracker/lib/core/theme/app_palette.dart:939-940` |
| `gamifTierPlatinumTagFg` | 0xFF7BC0E9 / 0xFF0173B7 | `learning_tracker/lib/core/theme/app_palette.dart:942-943` |
| `gamifTierPlatinumLockIcon` | 0xFF949DD0 / 0xFF5C6BC0 | `learning_tracker/lib/core/theme/app_palette.dart:945-946` |
| `gamifTierPremiumCardBg` | 0xFF2F1333 / 0xFFF3E5F5 | `learning_tracker/lib/core/theme/app_palette.dart:948-949` |
| `gamifTierPremiumSoftAccent` | 0xFF2F1333 / 0xFFE1BEE7 | `learning_tracker/lib/core/theme/app_palette.dart:951-952` |
| `gamifTierPremiumIconBg` | 0xFF201333 / 0xFFEDE7F6 | `learning_tracker/lib/core/theme/app_palette.dart:954-955` |
| `gamifTierPremiumIconFg` | 0xFFA993D1 / 0xFF7B53C0 | `learning_tracker/lib/core/theme/app_palette.dart:957-958` |
| `gamifTierPremiumIconBorder` | 0xFF9E84CB / 0xFFB39DDB | `learning_tracker/lib/core/theme/app_palette.dart:960-961` |
| `gamifTierPremiumTitle` | 0xFFBDAFE8 / 0xFF4527A0 | `learning_tracker/lib/core/theme/app_palette.dart:963-964` |
| `gamifTierPremiumMutedIcon` | 0xFFA992D2 / 0xFF9575CD | `learning_tracker/lib/core/theme/app_palette.dart:966-967` |
| `gamifTierPremiumBarBg` | 0xFFC184CC / 0xFFCE93D8 | `learning_tracker/lib/core/theme/app_palette.dart:969-970` |
| `gamifTierPremiumBarFill` | 0xFFD7AFE8 / 0xFF7B1FA2 | `learning_tracker/lib/core/theme/app_palette.dart:972-973` |
| `gamifTierPremiumLockIcon` | 0xFFD2AFE8 / 0xFF6A1B9A | `learning_tracker/lib/core/theme/app_palette.dart:975-976` |
| `gamifTierDiamondCardBg` | 0xFF132B33 / 0xFFE0F7FF | `learning_tracker/lib/core/theme/app_palette.dart:978-979` |
| `gamifTierDiamondSoftAccent` | 0xFF133033 / 0xFF80DEEA | `learning_tracker/lib/core/theme/app_palette.dart:981-982` |
| `gamifTierDiamondIconBg` | 0xFF133033 / 0xFFE0F7FA | `learning_tracker/lib/core/theme/app_palette.dart:984-985` |
| `gamifTierDiamondIconFg` | 0xFF69D8E6 / 0xFF007887 | `learning_tracker/lib/core/theme/app_palette.dart:987-988` |
| `gamifTierDiamondIconBorder` | 0xFF72D2DE / 0xFF4DD0E1 | `learning_tracker/lib/core/theme/app_palette.dart:990-991` |
| `gamifTierDiamondTitle` | 0xFFAFE5E8 / 0xFF006064 | `learning_tracker/lib/core/theme/app_palette.dart:993-994` |
| `gamifTierDiamondAccent` | 0xFF69D9E6 / 0xFF00ACC1 | `learning_tracker/lib/core/theme/app_palette.dart:996-997` |
| `gamifTierDiamondTagBg` | 0xFF133033 / 0xFFB2EBF2 | `learning_tracker/lib/core/theme/app_palette.dart:999-1000` |
| `gamifTierDiamondTagFg` | 0xFF7BE0E9 / 0xFF006B75 | `learning_tracker/lib/core/theme/app_palette.dart:1002-1003` |
| `gamifTierEliteCardBg` | 0xFF33131E / 0xFFFCE4EC | `learning_tracker/lib/core/theme/app_palette.dart:1005-1006` |
| `gamifTierEliteSoftAccent` | 0xFF33131E / 0xFFF8BBD0 | `learning_tracker/lib/core/theme/app_palette.dart:1008-1009` |
| `gamifTierEliteIconFg` | 0xFFE97BA0 / 0xFFEC407A | `learning_tracker/lib/core/theme/app_palette.dart:1011-1012` |
| `gamifTierEliteIconBorder` | 0xFFE66993 / 0xFFF48FB1 | `learning_tracker/lib/core/theme/app_palette.dart:1014-1015` |
| `gamifTierEliteDeepAccent` | 0xFFE8AFC8 / 0xFFAD1457 | `learning_tracker/lib/core/theme/app_palette.dart:1017-1018` |
| `gamifTierEliteMutedIcon` | 0xFFE97BA0 / 0xFFF06292 | `learning_tracker/lib/core/theme/app_palette.dart:1020-1021` |
| `gamifTierEliteBarFill` | 0xFFE97BA0 / 0xFFE91E63 | `learning_tracker/lib/core/theme/app_palette.dart:1023-1024` |
| `gamifTierEliteLockIcon` | 0xFFE67EA7 / 0xFFC2185B | `learning_tracker/lib/core/theme/app_palette.dart:1026-1027` |
| `gamifTierCustomBorder` | 0xFF263041 / 0xFFE0E0E0 | `learning_tracker/lib/core/theme/app_palette.dart:1029-1030` |
| `gamifTierCustomIconBg` | 0xFF1E2532 / 0xFFF5F5F5 | `learning_tracker/lib/core/theme/app_palette.dart:1032-1033` |
| `progressStreakActiveDay` | 0xFF0C2E86 / 0xFF103BAC | `learning_tracker/lib/core/theme/app_palette.dart:1038-1039` |
| `progressStreakTodayRing` | 0xFF9AA2B6 / 0xFF9FA8BD | `learning_tracker/lib/core/theme/app_palette.dart:1042-1043` |
| `progressLifetimePartial` | 0xFF332A13 / 0xFFFFD26A | `learning_tracker/lib/core/theme/app_palette.dart:1048-1049` |
| `progressLifetimeNoneOnLight` | 0xFF36425A / 0xFFB8C0CC | `learning_tracker/lib/core/theme/app_palette.dart:1052-1053` |
| `progressPointsBarFill` | 0xFFF2D9B3 | `learning_tracker/lib/core/theme/app_palette.dart:1068-1068` |
| `progressTierStreakAccent` | 0xFFE66970 / 0xFFFF6F77 | `learning_tracker/lib/core/theme/app_palette.dart:1071-1072` |
| `progressTierPointsAccent` | 0xFFE6C269 / 0xFFE4A100 | `learning_tracker/lib/core/theme/app_palette.dart:1075-1076` |
| `progressTierSiyumimAccent` | 0xFFEBC15A / 0xFFF8C146 | `learning_tracker/lib/core/theme/app_palette.dart:1090-1091` |
| `progressSiyumHeroText` | 0xFFE8D4AF / 0xFF7A4F00 | `learning_tracker/lib/core/theme/app_palette.dart:1096-1097` |
| `progressChazaraSegment` | 0xFFE6B469 / 0xFFF2A93B | `learning_tracker/lib/core/theme/app_palette.dart:1100-1101` |
| `progressBarAxisLabel` | 0xFF98A2B3 / 0xFF8A91A5 | `learning_tracker/lib/core/theme/app_palette.dart:1104-1105` |
| `progressBarLegendLabel` | 0xFFAAAFBA / 0xFF5E6678 | `learning_tracker/lib/core/theme/app_palette.dart:1108-1109` |
| `progressLifetimeCardGradientStart` | 0xFF10306D / 0xFF153E8C | `learning_tracker/lib/core/theme/app_palette.dart:1112-1113` |
| `progressLifetimeCardGradientEnd` | 0xFF28518E / 0xFF3D7DDA | `learning_tracker/lib/core/theme/app_palette.dart:1125-1126` |
| `progressLifetimePageBgTop` | 0xFF131F33 / 0xFFE8EEF8 | `learning_tracker/lib/core/theme/app_palette.dart:1129-1130` |
| `progressLifetimePageBgMid` | 0xFF131F33 / 0xFFF2F6FD | `learning_tracker/lib/core/theme/app_palette.dart:1133-1134` |
| `progressLifetimePageBgBottom` | 0xFF131C33 / 0xFFF8FAFF | `learning_tracker/lib/core/theme/app_palette.dart:1137-1138` |
| `progressSettingsAppBar` | 0xFFEAEEF5 / 0xFF2C382F | `learning_tracker/lib/core/theme/app_palette.dart:1141-1142` |
| `progressSettingsPageBgTop` | 0xFF263041 / 0xFFEDE8E1 | `learning_tracker/lib/core/theme/app_palette.dart:1146-1147` |
| `progressSettingsPageBgMid` | 0xFF2E2818 / 0xFFF4F1EA | `learning_tracker/lib/core/theme/app_palette.dart:1150-1151` |
| `progressSettingsPageBgBottom` | 0xFF2F2617 / 0xFFFAF8F5 | `learning_tracker/lib/core/theme/app_palette.dart:1154-1155` |
| `progressSettingsCardGradientStart` | 0xFF1D291F / 0xFF263529 | `learning_tracker/lib/core/theme/app_palette.dart:1159-1160` |
| `progressSettingsCardGradientMid` | 0xFF2D3F31 / 0xFF3A5240 | `learning_tracker/lib/core/theme/app_palette.dart:1163-1164` |
| `progressSettingsCardGradientEnd` | 0xFFAABAAD / 0xFF5C7560 | `learning_tracker/lib/core/theme/app_palette.dart:1167-1168` |
| `statCardHighlightCoral` | 0xFFE66970 / 0xFFFF6E76 | `learning_tracker/lib/core/theme/app_palette.dart:1171-1172` |
| `statCardValueInk` | 0xFFB5C1E2 / 0xFF11182C | `learning_tracker/lib/core/theme/app_palette.dart:1175-1176` |
| `statCardLabelMuted` | 0xFF98A2B3 / 0xFF7C8595 | `learning_tracker/lib/core/theme/app_palette.dart:1179-1180` |
| `preferenceSubtitleGrey` | 0xFF98A2B3 / 0xFF929BAA | `learning_tracker/lib/core/theme/app_palette.dart:1185-1186` |
| `preferenceTitleInk` | 0xFFBEC7D9 / 0xFF1D2432 | `learning_tracker/lib/core/theme/app_palette.dart:1189-1190` |
| `preferenceSegmentedBorder` | 0xFF18202E / 0xFFD7DEEA | `learning_tracker/lib/core/theme/app_palette.dart:1193-1194` |
| `dialogCancelButtonBg` | 0xFF1E2532 / 0xFFF0F1F5 | `learning_tracker/lib/core/theme/app_palette.dart:1197-1198` |
| `sacredTimeLockShabbosBg` | 0xFF0D1947 / 0xFF11215C | `learning_tracker/lib/core/theme/app_palette.dart:1201-1202` |
| `sacredTimeLockShabbosYomTovBg` | 0xFF261C54 / 0xFF31246C | `learning_tracker/lib/core/theme/app_palette.dart:1205-1206` |
| `sacredTimeLockYomKippurBg` | 0xFF141B27 / 0xFF1A2333 | `learning_tracker/lib/core/theme/app_palette.dart:1209-1210` |
| `sacredTimeHeaderBg` | 0xFF0D2B7C / 0xFF11389F | `learning_tracker/lib/core/theme/app_palette.dart:1213-1214` |
| `settingsProfileBadgeParentBg` | 0xFF132533 / 0xFFE8F4FD | `learning_tracker/lib/core/theme/app_palette.dart:1217-1218` |
| `settingsProfileBadgeParentText` | 0xFF7CAFE8 / 0xFF1565C0 | `learning_tracker/lib/core/theme/app_palette.dart:1222-1223` |
| `settingsProfileBadgeTutorBg` | 0xFF332713 / 0xFFFFF3E0 | `learning_tracker/lib/core/theme/app_palette.dart:1227-1228` |
| `profileModeCardBg` | 0xFF1E2532 / 0xFFF2F4F7 | `learning_tracker/lib/core/theme/app_palette.dart:1241-1242` |
| `settingsProfileAvatarRing` | 0xFF151F31 / 0xFFCFD8EA | `learning_tracker/lib/core/theme/app_palette.dart:1246-1247` |
| `settingsProfileCardShadow` | 0x19000000 / 0x121D2939 | `learning_tracker/lib/core/theme/app_palette.dart:1250-1251` |
| `settingsProfileParentCardShadow` | 0x1C000000 / 0x140038A8 | `learning_tracker/lib/core/theme/app_palette.dart:1254-1255` |
| `settingsProfileNoBackupAccent` | 0xFFD5A97B / 0xFFCE8A41 | `learning_tracker/lib/core/theme/app_palette.dart:1258-1259` |
| `introAccentInk` | 0xFFB9C9FF / 0xFF1A36A5 | `learning_tracker/lib/core/theme/app_palette.dart:1277-1278` |
| `onboardingChildIconBg` | 0xFF241E38 / 0xFFE8E0FF | `learning_tracker/lib/core/theme/app_palette.dart:1290-1291` |
| `progressOverallStatsGradientStart` | 0xFF0E3392 | `learning_tracker/lib/core/theme/app_palette.dart:1310-1310` |
| `progressOverallStatsGradientMid` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1318-1318` |
| `progressOverallStatsGradientEnd` | 0xFF2B5FD9 | `learning_tracker/lib/core/theme/app_palette.dart:1323-1323` |
| `progressLifetimeCardGradientMid` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1342-1342` |
| `progressFixedChipBlueIcon` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1360-1360` |
| `gamifTierBronzeIconFg` | 0xFF332513 / 0xFFFFFFFF | `learning_tracker/lib/core/theme/app_palette.dart:1379-1380` |
| `gamifProgressSummaryFill` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1391-1391` |
| `gamifProgressSummaryBadgeFill` | 0xFFD51F1B | `learning_tracker/lib/core/theme/app_palette.dart:1401-1401` |
| `signInCtaGradientStart` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1411-1411` |
| `signInCtaGradientEnd` | 0xFF2B5FD9 | `learning_tracker/lib/core/theme/app_palette.dart:1418-1418` |
| `signInErrorSnackbarBg` | 0xFF8A5306 | `learning_tracker/lib/core/theme/app_palette.dart:1431-1431` |
| `inviteSentSnackbarBg` | 0xFF388E3C | `learning_tracker/lib/core/theme/app_palette.dart:1444-1444` |
| `accountPickerAlertBadgeIcon` | 0xFFB43A4A | `learning_tracker/lib/core/theme/app_palette.dart:1456-1456` |
| `sacredTimeLockYomTovBg` | 0xFF4A2A8A | `learning_tracker/lib/core/theme/app_palette.dart:1468-1468` |
| `brandBlueDeepFill` | 0xFF163797 / 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1494-1495` |
| `chartRedDeepFill` | 0xFFB43A4A | `learning_tracker/lib/core/theme/app_palette.dart:1508-1508` |
| `preferenceSegmentedSelectedFill` | 0xFF2B5FD9 | `learning_tracker/lib/core/theme/app_palette.dart:1522-1522` |
| `transparent` | 0x00000000 | `learning_tracker/lib/core/theme/app_palette.dart:1525-1525` |
| `profileModeIconMutedBg` | 0xFF263041 / 0xFFE4E8EF | `learning_tracker/lib/core/theme/app_palette.dart:1537-1538` |
| `addProfileFormLabel` | 0xFFEAEEF5 / 0xFF333333 | `learning_tracker/lib/core/theme/app_palette.dart:1545-1546` |
| `profileAvatarGradientStart` | 0xFF1D2636 / 0xFFF2F5FC | `learning_tracker/lib/core/theme/app_palette.dart:1553-1554` |
| `profileAvatarGradientEnd` | 0xFF161E2C / 0xFFE6ECF8 | `learning_tracker/lib/core/theme/app_palette.dart:1558-1559` |
| `peachTintIconAccent` | 0xFFE1D2B6 / 0xFFB45309 | `learning_tracker/lib/core/theme/app_palette.dart:1566-1567` |
| `deleteAccountDangerRed` | 0xFFF0857B / 0xFFB00020 | `learning_tracker/lib/core/theme/app_palette.dart:1575-1576` |
| `trackProgramLockedBg` | 0xFF16233F / 0xFFF0F4FF | `learning_tracker/lib/core/theme/app_palette.dart:1617-1618` |
| `trackProgramLockedIcon` | 0xFFB9C9FF / 0xFF6B84D6 | `learning_tracker/lib/core/theme/app_palette.dart:1623-1624` |
| `trackProgramLockedText` | 0xFFB9C9FF / 0xFF4A5C99 | `learning_tracker/lib/core/theme/app_palette.dart:1628-1629` |
| `trackAddFabFill` | 0xFF1442B8 | `learning_tracker/lib/core/theme/app_palette.dart:1640-1640` |
| `chazaraTinyButtonBg` | 0xFF1E2532 / 0xFFF1F3F7 | `learning_tracker/lib/core/theme/app_palette.dart:1649-1650` |
| `chazaraReadOnlyHintBg` | 0xFF16233F / 0xFFEFF2FF | `learning_tracker/lib/core/theme/app_palette.dart:1657-1658` |
| `chazaraReadOnlyStageBadgeBg` | 0xFF16233F / 0xFFE9ECFF | `learning_tracker/lib/core/theme/app_palette.dart:1664-1665` |
| `calendarResetButtonBg` | 0xFF263041 / 0xFFE9EBF1 | `learning_tracker/lib/core/theme/app_palette.dart:1673-1674` |
| `calendarDateIconBg` | 0xFF16233F / 0xFFE6E8FF | `learning_tracker/lib/core/theme/app_palette.dart:1680-1681` |
| `calendarOffsetButtonBg` | 0xFF131C33 / 0xFFF4F6FA | `learning_tracker/lib/core/theme/app_palette.dart:1689-1690` |
| `curriculumMishnaPickerIcon` | 0xFFB9C9FF / 0xFF3F53BF | `learning_tracker/lib/core/theme/app_palette.dart:1700-1701` |
| `programFeaturedCardIcon` | 0xFFB9C9FF / 0xFF2E4BBB | `learning_tracker/lib/core/theme/app_palette.dart:1707-1708` |
| `programSelfPacedCtaText` | 0xFFE1D2B6 / 0xFF2E271E | `learning_tracker/lib/core/theme/app_palette.dart:1717-1718` |
| `goalHintChipInk` | 0xFF0E3392 | `learning_tracker/lib/core/theme/app_palette.dart:1729-1729` |
| `brandBlueLinkInk` | 0xFF7CA0FF / 0xFF354993 | `learning_tracker/lib/core/theme/app_palette.dart:1744-1745` |
| `overdueBadgeInk` | 0xFFDE8686 / 0xFFC22840 | `learning_tracker/lib/core/theme/app_palette.dart:1756-1757` |
| `warningSnackbarFill` | 0xFF8A5306 | `learning_tracker/lib/core/theme/app_palette.dart:1775-1775` |

ThemeData itself uses those palette values except contrast foreground black/white and brightness-dependent shadow/scrim listed above (`learning_tracker/lib/core/theme/app_theme.dart:87-106`, `:138-140`, `:358-369`).

## 2. Localization & direction

- Supported UI locales are English (`en`) and Hebrew (`he`), using generated `AppLocalizations` from ARB files (`learning_tracker/lib/l10n/app_localizations.dart:64-70`, `:96-99`; `learning_tracker/lib/l10n/app_en.arb`; `learning_tracker/lib/l10n/app_he.arb`). Flutter localization delegates for app, Material, Widgets, and Cupertino are registered in `MaterialApp.router` (`learning_tracker/lib/app/learning_tracker_app.dart:78-90`).
- `locale: null` lets Flutter resolve the device locale; code comments specify Hebrew device locale selects Hebrew/RTL and otherwise English. There is no in-app UI-language selector (`learning_tracker/lib/app/learning_tracker_app.dart:78-90`).
- Hebrew-domain-term display is a separate setting from UI locale: the Hebrew Terms toggle chooses Hebrew script vs locale-provided transliteration/English terms; ordinary UI labels follow the UI locale (`learning_tracker/lib/core/constants/hebrew_terms.dart:92-108`). Hebrew term constants include משנה (Mishnah), מסכת (Masechta), סדר (Seder), פרק (Perek), דף (Daf), and עמוד (Amud) (`hebrew_terms.dart:110-124`, `:150-167`).
- Hebrew font family is `Noto Sans Hebrew`; text-style documentation specifies Hebrew RTL, English LTR and bidirectional content (`learning_tracker/lib/core/theme/text_styles.dart:4-25`).
- ARB generation is configured with `lib/l10n/app_en.arb` as template and `app_localizations.dart` as generated output (`learning_tracker/l10n.yaml:1-3`); the Hebrew ARB is `learning_tracker/lib/l10n/app_he.arb:1`.

## 3. Navigation & information architecture

- Navigation is `auto_route` (`RootStackRouter`, material route type) with auth/profile/child-mode/PIN guards, declared in `learning_tracker/lib/app/router/app_router.dart:1-7`, `:57-76`. Unauthenticated/onboarding entry paths include `/intro` (initial), `/sign-in`, `/create-account`, `/account-picker`, `/onboarding`, `/empty-login`, `/permission-prompt`, `/profile-picker`, `/manage-learners`; action-link paths redirect to sign-in (`app_router.dart:77-116`).
- Authenticated shell path `/` has persistent tabs: `dashboard` (initial), `learn`, `progress`, `settings` (`app_router.dart:118-129`). Tabs show as Dashboard, Learn, Progress, Settings with dashboard/book/graph/gear icons; parent mode hides bottom navigation, while a tutor session retains it (`learning_tracker/lib/app/router/app_shell.dart:312-327`). Navigation bar is a rounded-top 28dp card surface with a subtle shadow (`app_shell.dart:328-361`).
- Additional registered route families: progress `/journey`, `/progress/recent`, `/progress/lifetime`; browse `/browse`, `/curriculum/:curriculumId/browse`, `/curriculum/:curriculumId/search`, `/text/:sefariaRef`; curriculum progress/settings `/curriculum/:curriculumId/progress`, `/curriculum/:curriculumId/settings`; schedule `/scheduler`, `/study-days/:curriculumId`; gamification/rewards `/gamification`, `/redeem`, `/parent-mode/pending-redemptions`, `/parent-mode/settings`, `/parent-mode/point-config`, `/parent-mode/reward-config`, `/parent-mode/pin-setup`; notifications `/notifications`; sacred time `/sacred-time/city`; track management/order `/parent-mode/tracks`, `/settings/tracks`, `/settings/tracks/detail`, `/curriculum/:curriculumId/order`; lifetime marking `/settings/lifetime`, `/settings/lifetime/:curriculumId`; tutoring `/tutor/manage-tutors`, `/tutor/my-grants`, `/tutor/audit-log`, `/tutor/invite`, `/invite`, `/tutor/decline` (`learning_tracker/lib/app/router/app_router.dart:131-310`).
- Shell context bars: cloud-born offline banner; profile switcher; parent viewing-child banner; tutor-mode indicator. Profile-switcher bar also wraps pushed subroutes globally. In parent-elevated child mode, bottom nav is hidden (`learning_tracker/lib/app/router/app_shell.dart:196-220`, `:244-310`, `:312-320`; `learning_tracker/lib/app/router/persistent_switcher_scaffold.dart:122-127`, `:157-203`).
- No app-level drawer or nested tab bars are defined by the root router; individual screens can provide local controls (`app_router.dart:76-312`).

## 4. Screen inventory

Screens below are grouped by feature, and include routed screens plus standalone flows in presentation screen folders. A screen's relevance flag is **Yes** if its screen purpose or displayed data touches the requested terms; **No** otherwise. Main composition is stated at screen-level and the line citation points to its screen declaration/build and, where available, the defining shared body/widgets.

| Screen / file | Purpose and primary composition | Learning-item relevance |
|---|---|---|
| `features/onboarding/presentation/screens/app_intro_screen.dart:1` (`AppIntroScreen`, `:54`, `:127-134`) | Intro/onboarding carousel, hero and page sections. | Yes — learning/Mishna explainer (`:330-356`). |
| `features/account/presentation/screens/sign_in_screen.dart:1` (`:39`, `:238-256`) | Sign-in form and auth actions in a safe-area scaffold. | No. |
| `features/account/onboarding/presentation/screens/onboarding_intent_screen.dart:1` (`OnboardingIntentStep`, `:28-45`) | Embedded branch chooser after profile creation; scrollable safe-area column of intent cards. | Yes — one choice starts a learning track (`:63-80`). |
| `features/account/onboarding/presentation/screens/signup_screen.dart:1` (`:33`, `:33-47`) | Account signup/auth form. | No. |
| `features/account/presentation/screens/account_picker_screen.dart:1` (`:42`, `:71-85`) | Choose/remove device accounts; account cards and dismissal actions. | No. |
| `features/onboarding/presentation/screens/onboarding_screen.dart:1` (`:63`, `:335-372`) | Onboarding state flow and step body, optional app bar. | Yes — curriculum/learning setup. |
| `features/onboarding/presentation/screens/empty_login_screen.dart:1` (`:25`, `:25-32`) | Signed-in zero-profile landing with account/settings actions. | No. |
| `features/onboarding/presentation/screens/permission_prompt_screen.dart:1` (`:24`, `:135-153`) | Notification/location permission choices. | No. |
| `features/onboarding/presentation/screens/learning_process_wizard_screen.dart:1` (`:28`, `:28-52`) | Learning-process configuration wizard. | Yes — learning stages. |
| `features/onboarding/presentation/screens/bulk_mark_screen.dart:1` (`:44`, `:44-65`) | Mark prior completions in bulk. | Yes — progress/completions. |
| `features/dashboard/presentation/screens/dashboard_screen.dart:1` (`:16`, `:16-24`) | Dashboard; assembled by `DashboardBody` and its mission/track cards (`features/dashboard/presentation/widgets/dashboard_body.dart:1`; `features/dashboard/presentation/widgets/active_track_card.dart:1`). | Yes — tracks/progress. |
| `features/learning/presentation/screens/learning_screen.dart:1` (`:24`, `:24-32`) | Current learning tasks/completion surface. | Yes — learning items/tracks/progress. |
| `features/progress/presentation/screens/progress_screen.dart:1` (`:38`, `:38-47`) | Progress summary/lenses. | Yes — progress. |
| `features/progress/presentation/screens/recent_activity_screen.dart:1` (`:41`, `:41-49`) | Recent learning/activity history. | Yes — progress/learning items. |
| `features/progress/presentation/screens/lifetime_knowledge_screen.dart:1` (`:37`, `:37-45`) | Lifetime learned-knowledge view. | Yes — learning items/progress. |
| `features/progress/presentation/screens/curriculum_progress_screen.dart:1` (`:22`, `:22-30`) | Progress for one curriculum. | Yes — curriculum/track/progress. |
| `features/progress/presentation/screens/siyumim_milestones_screen.dart:1` (`:32`, `:32-40`) | Siyum/milestone achievements. | Yes — completed learning/progress. |
| `features/content_browsing/presentation/screens/curriculum_list_screen.dart:1` (`:19`, `:19-27`) | Curriculum list and entry into browsing. | Yes — source/learning items. |
| `features/content_browsing/presentation/screens/content_hierarchy_screen.dart:1` (`:23`, `:23-44`) | Browse curriculum hierarchy with selectable items. | Yes — source/learning items. |
| `features/content_browsing/presentation/screens/content_search_screen.dart:1` (`:20`, `:20-33`) | Search curriculum/content. | Yes — source/learning items. |
| `features/content_browsing/presentation/screens/text_display_screen.dart:1` (`:38`, `:38-85`) | Display Hebrew/English source text and review/completion controls. | Yes — source/Mishnayos/learning items. |
| `features/scheduler/presentation/screens/scheduler_screen.dart:1` (`:18`, `:18-26`) | Daily schedule/task plan. | Yes — schedule/tracks/progress. |
| `features/scheduler/presentation/screens/goal_setup_screen.dart:1` (`:27`, `:27-35`) | Configure learning goal and pace/deadline. | Yes — learning/schedule. |
| `features/scheduler/presentation/screens/study_day_config_screen.dart:1` (`:68`, `:68-76`) | Configure per-curriculum study days. | Yes — schedule/track. |
| `features/tracks/setup/presentation/screens/track_management_hub_screen.dart:1` (`:14`, `:22-25`) | Track hub route wrapper around `TrackManagementBody`, which owns list/empty/error states and add flow. | Yes — tracks. |
| `features/tracks/setup/presentation/screens/track_detail_screen.dart:1` (`:178`, `:187-196`) | One track's details, goal and progress summary. | Yes — track/progress. |
| `features/tracks/setup/presentation/screens/edit_track_screen.dart:1` (`:70`, `:79-110`) | Edit track name, goal, study days and chazara config. | Yes — track/schedule/learning. |
| `features/tracks/setup/presentation/screens/add_track_flow_screen.dart:1` (`:114-132`; `AddTrackFlow`) | Standalone eight-step add-track wizard; step modules include curriculum/program, scope, goal, study days, starting position, bulk mark, and chazara (`:22-35`). | Yes — track/source/learning/schedule/progress. |
| `features/tracks/track_order/presentation/screens/track_learning_order_screen.dart:1` (`:20`, `:40-64`) | Reorder track-specific sedarim/masechtos. | Yes — track/source/order. |
| `features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart:1` (`:19`, `:29`) | Reorder whole-curriculum learning order; draggable order items and reset dialog (`features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart:1`, `reset_order_dialog.dart`). | Yes — learning/source/order. |
| `features/profiles/presentation/screens/profile_picker_screen.dart:1` (`:31`, `:39`) | Select an active learner profile. | Yes — profile-specific learning context. |
| `features/profiles/presentation/screens/manage_learners_screen.dart:1` (`:15`, `:15-34`) | Manage/create learner profiles. | No. |
| `features/profiles/presentation/screens/parent_settings_screen.dart:1` (`:68`) | Parent-mode settings and actions. | Yes — includes track and progress management (`:661-707`). |
| `features/profiles/presentation/screens/parent_track_management_screen.dart:1` (`:21`, `:29`) | Parent-mode track management. | Yes — tracks. |
| `features/profiles/presentation/screens/pin_flow_screen.dart:1` (`:31`, `:373`) | Parent PIN setup/verify/change flow wrappers. | No. |
| `features/settings/presentation/screens/settings_screen.dart:1` (`:46`, `:79-121`) | Grouped app/account/profile/settings list. Track and lifetime-management rows are included (`:183-243`). | Yes — tracks/learning. |
| `features/settings/presentation/screens/curriculum_settings_screen.dart:1` (`:21`, `:34`) | Curriculum-specific configuration. | Yes — curriculum/schedule. |
| `features/settings/presentation/screens/scope_selection_screen.dart:1` (`:20`, `:30`) | Choose curriculum scope. | Yes — source/curriculum. |
| `features/settings/presentation/screens/lifetime_marking_screen.dart:1` (`:31-40`) | Mark lifetime prior learning across curricula. | Yes — progress/learning items. |
| `features/settings/presentation/screens/lifetime_marking_screen.dart:1` (`LifetimeCurriculumMarkingScreen`, `:307-320`) | Mark prior learning for one curriculum. | Yes — curriculum/learning progress. |
| `features/gamification/presentation/screens/gamification_screen.dart:1` (`:66`, `:73`) | Child/adult achievements, points, streaks and rewards. | Yes — progress/streak. |
| `features/gamification/presentation/screens/child_redemption_screen.dart:1` (`:74`) | Child prize redemption. | No. |
| `features/gamification/presentation/screens/parent_pending_redemptions_screen.dart:1` (`:56`) | Parent approves/declines prize requests. | No. |
| `features/gamification/presentation/screens/point_config_screen.dart:1` (`:138`, `:145`) | Configure point awards. | No. |
| `features/gamification/presentation/screens/reward_configuration_screen.dart:1` (`:39`, `:47`) | Configure rewards. | No. |
| `features/notifications/presentation/screens/notifications_screen.dart:1` (`:10`) | Notification preferences. | No. |
| `features/sacred_time/presentation/screens/city_picker_screen.dart:1` (`:15`, `:33-44`) | Search/select city for sacred-time calculations. | No. |
| `features/tutoring/presentation/screens/manage_tutors_screen.dart:1` (`:32`) | Manage connected tutors. | No. |
| `features/tutoring/presentation/screens/manage_grants_screen.dart:1` (`:26`) | Tutor manages learner grants. | No. |
| `features/tutoring/presentation/screens/tutor_audit_log_screen.dart:1` (`:23`) | Review tutoring audit activity. | No. |
| `features/tutoring/presentation/screens/invite_tutor_screen.dart:1` (`:34`) | Invite a tutor. | No. |
| `features/tutoring/presentation/screens/accept_invite_screen.dart:1` (`:54`) | Accept tutor invite link. | No. |
| `features/tutoring/presentation/screens/decline_invite_screen.dart:1` (`:44`) | Decline tutor invite. | No. |
| `features/tutoring/presentation/screens/tutor_pin_entry_gate.dart:1` (`:30`) | Tutor PIN gate before entering learner context. | No. |
| `features/tutoring/presentation/screens/tutor_pin_entry_dialog.dart:1` (`:36`) | Tutor PIN verification dialog. | No. |
| `features/tutoring/presentation/screens/tutor_pin_setup_screen.dart:1` (`:42`) | Set tutor PIN. | No. |
| `features/tutoring/presentation/screens/tutor_pin_reset_screen.dart:1` (`:36`) | Reset tutor PIN. | No. |

## 5. Reusable components

- Shared core widgets: `LoadingIndicator` is a centered circular progress indicator (`learning_tracker/lib/core/widgets/loading_indicator.dart:7-31`); `EmptyState` centers icon/illustration, title/message and optional action with 32dp padding (`core/widgets/empty_state.dart:6-39`); `ErrorDisplay` shows error copy plus retry action (`core/widgets/error_display.dart:4-45`); `InlineAsyncError` is inline retry/error feedback (`core/widgets/inline_async_error.dart:1-55`).
- `AppErrorView` maps typed errors to localized icon/title/subtitle and optional retry or issue-report action; network errors use offline/retry treatment, validation errors no retry, permission/not-found/conflict/internal have distinct mapped treatments (`learning_tracker/lib/core/widgets/app_error_view.dart:3-17`, `:79-148`, `:150-180`).
- `StatCard` is the shared outlined card/stat surface, zero elevation, configurable padding (default 14dp) and radius (`learning_tracker/lib/core/widgets/stat_card.dart:25-31`, `:64-94`). `PreferenceListTile` is a rounded preference-row pattern (`core/widgets/preference_list_tile.dart:1-35`, `:130-175`).
- `AnimatedProgressBar` animates clamped 0..1 values using `TweenAnimationBuilder`, default 6dp height, 600ms ease-in-out, pill clipping (`learning_tracker/lib/core/widgets/animated_progress_bar.dart:3-26`, `:44-74`). Dashboard/progress have feature-level cards and charts (`features/dashboard/presentation/widgets/`; `features/progress/presentation/widgets/`).
- Shared `showAppDialog` / `showAppConfirmDialog` use a safe-area, max-480dp, height-limited rounded card with scrollable body and pinned actions; confirm layout is icon/title/message plus confirm/cancel (`learning_tracker/lib/core/widgets/app_dialog.dart:27-102`, `:104-180`). Theme-level dialogs and sheets are card-surface with 16dp and top-24dp radii respectively (`learning_tracker/lib/core/theme/app_theme.dart:352-369`).
- Profile switcher is a modal sheet (`learning_tracker/lib/features/profiles/presentation/widgets/profile_switcher_sheet.dart:20-31`); settings exposes account actions in a bottom sheet (`features/settings/presentation/widgets/account_actions_sheet.dart:25-52`).
- Track-specific shared parts: `TrackManagementBody` owns management list/empty/error/add flows (`features/tracks/setup/presentation/widgets/track_management_body.dart:1`, `features/tracks/setup/presentation/screens/track_management_hub_screen.dart:5-24`); `LearningTrackCard`, track info card and curriculum/program/label steps are separated into `features/tracks/setup/presentation/widgets/learning_track_card.dart:1`, `track_info_card.dart`, `curriculum_picker_step.dart`, `program_selection_step.dart`, `track_label_step.dart`; order rows use `draggable_order_item.dart`.

## 6. State patterns

- Presentation state predominantly uses Riverpod `ConsumerWidget`/`ConsumerStatefulWidget`; route screens watch providers and branch on `AsyncValue` states. The common loading component is circular; common failures use `AppErrorView` or inline error/retry (`learning_tracker/lib/core/widgets/loading_indicator.dart:7-31`; `core/widgets/app_error_view.dart:25-42`, `:79-120`; `core/widgets/inline_async_error.dart:1-55`).
- Empty data is generally represented by feature empty states; the track hub explicitly shares its list/empty/error/add UI in `TrackManagementBody` (`learning_tracker/lib/features/tracks/setup/presentation/screens/track_management_hub_screen.dart:5-24`).
- Network error maps to localized no-connection message with retry; top-of-shell offline banner is shown only for cloud-born users when connectivity says offline. During connectivity loading/unknown, shell's `orElse` treats it as online (`learning_tracker/lib/core/widgets/app_error_view.dart:150-160`; `learning_tracker/lib/app/router/app_shell.dart:196-220`).
- Sync feedback appears in backup/sync settings and at shell level; account/local-born paths are not all shown the cloud-only banner (`learning_tracker/lib/app/router/app_shell.dart:217-220`; `learning_tracker/lib/features/settings/presentation/widgets/backup_sync_section.dart:1-35`).

## 7. Accessibility

- Shell context bars size to text scaling, with minimum interactive dimension 48dp and added 1dp safety; shell includes the system inset. This explicitly accounts for Hebrew marks and large text (`learning_tracker/lib/app/router/app_shell.dart:21-44`). Profile switcher tap target has 48dp min height and uses ellipsis on long names (`app_shell.dart:610-653`).
- Shared dialogs use `MediaQuery`, `SafeArea`, constrain width/height, account for keyboard inset, and keep the body scrollable; code comments explicitly state they adapt to text scaling (`learning_tracker/lib/core/widgets/app_dialog.dart:7-16`, `:122-165`).
- Foreground text on filled colors chooses the higher-contrast of white/near-black. Palette documentation describes paired foreground tokens as meeting 4.5:1; explicit contrast checking appears in theme code (`learning_tracker/lib/core/theme/app_theme.dart:87-106`; `learning_tracker/lib/core/theme/app_palette.dart:18-22`).
- Semantic labels/tooltips exist on controls including active-track carousel previous/next, progress tier counters, track selection clearing, notification rows, and order reset (`learning_tracker/lib/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart:80-106`; `features/progress/presentation/widgets/progress_tier_counter_row.dart:80-133`, `:188-200`; `features/tracks/setup/presentation/steps/step_starting_position.dart:270-282`; `features/notifications/presentation/screens/notifications_screen.dart:275-294`; `features/tracks/track_order/presentation/screens/track_learning_order_screen.dart:70-74`). This is an inventory of visible examples, not a claim that all controls are labeled.
- Hebrew/English font and direction support is documented in `learning_tracker/lib/core/theme/text_styles.dart:4-25`. Font scaling is not globally disabled in app setup (`learning_tracker/lib/app/learning_tracker_app.dart:57-98`).

## 8. Interaction patterns

- Main navigation uses persistent AutoTabsScaffold tabs. Selecting profile/role opens the profile-switcher bottom sheet; context bars offer profile switching or parent-mode exit (`learning_tracker/lib/app/router/app_shell.dart:210-220`, `:312-327`, `:590-608`, `:694-710`; `learning_tracker/lib/app/router/persistent_switcher_scaffold.dart:122-127`).
- Track management opens a multi-step add wizard; detail/edit views expose goal, study-day and chazara changes; learning order uses draggable rows and reset confirmation (`learning_tracker/lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart:114-132`; `features/tracks/setup/presentation/screens/edit_track_screen.dart:70-110`; `features/tracks/track_order/presentation/screens/track_learning_order_screen.dart:63-74`; `features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart:1`; `features/tracks/whole_curriculum_order/presentation/widgets/reset_order_dialog.dart:1`).
- Animated progress transitions are 600ms ease-in-out by default (`learning_tracker/lib/core/widgets/animated_progress_bar.dart:17-25`, `:49-69`). The shell has adaptive context bars; onboarding/add-track pages use step transitions (`features/tracks/setup/presentation/screens/add_track_flow_screen.dart:134-143`).
- Snack bars provide transient success/error feedback and use floating theme behavior (`learning_tracker/lib/core/theme/app_theme.dart:371-378`; examples: `features/tracks/setup/presentation/screens/track_detail_screen.dart:939-940`, `features/tracks/track_order/presentation/screens/track_learning_order_screen.dart:296-306`).
- Confirmation dialogs are used for destructive/irreversible choices; shared confirm dialog defaults to dismissible and returns false when dismissed (`learning_tracker/lib/core/widgets/app_dialog.dart:50-67`, `:70-102`). Account picker supports swipe dismissal/removal (`learning_tracker/lib/features/account/presentation/screens/account_picker_screen.dart:300-330`); content item tiles use long-press to open review-count details (`learning_tracker/lib/features/content_browsing/presentation/widgets/content_item_tile.dart:90-110`); profile grid/card supports long-press actions (`learning_tracker/lib/features/profiles/presentation/widgets/profile_grid.dart:52-66`, `profile_card.dart:8-45`).
- FABs and local tab controls are screen-specific rather than part of the root shell; root-level tabs are only the four destinations described in §3 (`learning_tracker/lib/app/router/app_shell.dart:312-327`).
