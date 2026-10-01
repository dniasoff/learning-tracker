---
name: Learning Tracker — Sub-tracks
description: Visual contract for the Sub-tracks feature inside the existing Learning Tracker Flutter app. Inherits Material 3 + AppTheme/AppPalette; specifies only what Sub-tracks uses or adds.
status: final
updated: 2026-10-01
sources:
  - docs/planning/prds/prd-sub-tracks-2026-09-30/prd.md  # wiki "PRD: Sub-tracks" (oWEwMw7iGT)
  - docs/planning/prds/prd-sub-tracks-2026-09-30/addendum.md  # wiki addendum (yBGcGFULnc)
  - docs/brainstorming/brainstorm-multi-source-mishnayos-tracking-2026-08-24/brainstorm.html
  - learning_tracker/lib/core/theme/app_palette.dart
  - learning_tracker/lib/core/theme/app_theme.dart
  - learning_tracker/lib/core/theme/text_styles.dart
  - learning_tracker/lib/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart
  - learning_tracker/lib/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart
  - EXPERIENCE.md  # peer spine — behaviour
# Token naming: every color key is the AppPalette getter in kebab-case
# (brand-blue == context.colors.brandBlue); `-dark` = the dark-brightness value
# of the same getter. Only tokens Sub-tracks uses are listed. Everything else is
# inherited from AppPalette by name and is not restated here, including
# brandBlueBright, brandCoral, brandGold, brandError(+Soft), streakActive,
# goldTrophy, childViewAccent, switcherBarBackground, sacredTimeLockShabbosBg,
# sacredTimeLockShabbosYomTovBg, sacredTimeLockYomKippurBg, sacredTimeLockYomTovBg.
# Keys marked NEW have no AppPalette getter yet.
colors:
  brand-blue: '#1442B8'
  brand-blue-dark: '#7CA0FF'
  brand-blue-soft: '#E4EBFA'
  brand-blue-soft-dark: '#16233F'
  brand-coral-soft: '#FDE9E2'
  brand-coral-soft-dark: '#2E1C14'
  brand-warning-soft: '#FBF0DC'
  brand-warning-soft-dark: '#2E220E'
  brand-warning-deep: '#8A5306'
  brand-warning-deep-dark: '#F0C883'
  brand-gold-soft: '#E3EDD3'
  brand-gold-soft-dark: '#1B2A12'
  brand-cream: '#F7F8FB'
  brand-cream-dark: '#0B0F1A'
  brand-cream-card: '#FFFFFF'
  brand-cream-card-dark: '#151A26'
  brand-cream-soft: '#EFF2F7'
  brand-cream-soft-dark: '#1E2532'
  brand-outline: '#D4DCE8'
  brand-outline-dark: '#263041'
  brand-ink: '#101828'
  brand-ink-dark: '#EAEEF5'
  brand-ink-2: '#2B3444'
  brand-ink-2-dark: '#C3CBD8'
  brand-ink-muted: '#5A6474'
  brand-ink-muted-dark: '#98A2B3'
  brand-ink-soft: '#6A7484'
  brand-ink-soft-dark: '#828D9E'
  curriculum-mishna: '#277B3C'
  curriculum-mishna-dark: '#62D186'
  status-success-muted: '#3BDD87'
  status-success-muted-dark: '#72DEA4'
  status-success-soft-bg: '#EAF5EA'
  status-success-soft-bg-dark: '#173017'
  status-success-soft-text: '#3A7C3A'
  status-success-soft-text-dark: '#9ACA9A'
  progress-lifetime-partial: '#FFD26A'
  progress-lifetime-partial-dark: '#332A13'
  progress-lifetime-none-on-light: '#B8C0CC'
  progress-lifetime-none-on-light-dark: '#36425A'
  settings-profile-badge-tutor-bg: '#FFF3E0'
  settings-profile-badge-tutor-bg-dark: '#332713'
  # NEW — proposed AppPalette getter `tristatePartialAccent`. Light reuses
  # progressLifetimePartial; dark reuses statusWarning (dark) because
  # progressLifetimePartial dark (#332A13) is a fill tone that vanishes at
  # 12% alpha on a dark card. Values from the approved dark mocks.
  tristate-partial-accent: '#FFD26A'
  tristate-partial-accent-dark: '#E6B96A'
typography:
  # AppTextStyles (text_styles.dart). Plus Jakarta Sans for Latin; Noto Sans Hebrew for Hebrew script.
  # Inherited unchanged and not restated: headline-large/medium, title-large, body-large, label-medium,
  # hebrew headline/title variants, button (15/600), chip (13).
  headline-small: { fontFamily: Plus Jakarta Sans, fontSize: 24px, fontWeight: '600', lineHeight: '1.4' }
  title-medium: { fontFamily: Plus Jakarta Sans, fontSize: 18px, fontWeight: '600', lineHeight: '1.4' }
  title-small: { fontFamily: Plus Jakarta Sans, fontSize: 16px, fontWeight: '600', lineHeight: '1.4' }
  body-medium: { fontFamily: Plus Jakarta Sans, fontSize: 14px, fontWeight: '400', lineHeight: '1.5' }
  body-small: { fontFamily: Plus Jakarta Sans, fontSize: 12px, fontWeight: '400', lineHeight: '1.5' }
  label-large: { fontFamily: Plus Jakarta Sans, fontSize: 14px, fontWeight: '500', lineHeight: '1.4' }
  label-small: { fontFamily: Plus Jakarta Sans, fontSize: 11px, fontWeight: '500', lineHeight: '1.4' }
  hebrew-body-medium: { fontFamily: Noto Sans Hebrew, fontSize: 16px, fontWeight: '400', lineHeight: '1.6' }
  app-bar-title: { fontFamily: Plus Jakarta Sans, fontSize: 18px, fontWeight: '700', letterSpacing: 0.3px }
rounded:
  # app_theme.dart values. px == Flutter logical dp throughout.
  # Inherited and not restated: tooltip 8, snackbar 12, dialog 16, nav-bar-top 28.
  checkbox: 4px
  tag: 6px          # NEW — non-interactive source / state tags (approved mocks)
  text-button: 8px
  input: 12px
  card: 18px
  chip: 20px
  sheet-top: 24px
  app-dialog: 28px
  full: 9999px      # pill alias; the theme's literal button radius is 30 on 48dp-high buttons
spacing:
  # The app has no shared spacing scale. These named tokens are NEW names for
  # values the theme and approved mocks already use.
  '3': 12px
  '5': 24px
  gutter-mobile: 16px
  touch-target: 48px
  progress-bar-height: 6px
  dialog-max-width: 480px
  form-max-width: 600px      # [ASSUMPTION] from tablet brief "forms centred max ~600px"
  nav-rail-width: 240px      # approved tablet mocks (240–256px)
  tree-indent: 20px          # lifetime tree depth indent
components:
  subtrack-row:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
    title: '{typography.title-small}'
    position-text: '{typography.body-medium}'
  plus-one-button:
    background: '{colors.brand-blue}'
    foreground: '#FFFFFF'
    radius: '{rounded.full}'
    min-height: '{spacing.touch-target}'
  up-to-button:
    foreground: '{colors.brand-blue}'
    radius: '{rounded.text-button}'
    min-height: '{spacing.touch-target}'
  up-to-picker:
    sheet-radius: '{rounded.sheet-top}'
    dialog-radius: '{rounded.app-dialog}'
    dialog-max-width: '{spacing.dialog-max-width}'
    confirm-button: '{components.plus-one-button}'
  tristate-row-complete:
    tint: '{colors.status-success-muted}'   # row background at 12% alpha
    checkbox: checked
  tristate-row-partial:
    tint: '{colors.progress-lifetime-partial}'
    checkbox-fill: '{colors.tristate-partial-accent}'
    checkbox: indeterminate-dash
  tristate-row-empty:
    tint: '{colors.progress-lifetime-none-on-light}'
    checkbox-border: '{colors.brand-ink-soft}'   # 4.73:1 light / 5.18:1 dark
    checkbox: empty
  source-chip-home:
    background: '{colors.brand-cream-soft}'
    foreground: '{colors.brand-ink-muted}'
    radius: '{rounded.tag}'
    text: '{typography.label-small}'
  source-chip-school-year:
    background: '{colors.brand-blue-soft}'
    foreground: '{colors.brand-blue}'
    radius: '{rounded.tag}'
    text: '{typography.label-small}'
  source-chip-ongoing:
    background: '{colors.brand-warning-soft}'
    foreground: '{colors.brand-warning-deep}'
    icon: '{colors.brand-warning-deep}'
    radius: '{rounded.tag}'
    text: '{typography.label-small}'
  shortfall-card:
    background: '{colors.brand-warning-soft}'
    foreground: '{colors.brand-warning-deep}'
    icon: '{colors.brand-warning-deep}'     # 5.6:1 light / 9.84:1 dark
    radius: '{rounded.card}'
  on-track-card:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
    status-on-track: '{colors.status-success-soft-text}'
    status-behind-pace: '{colors.brand-warning-deep}'
    status-too-early: '{colors.brand-ink-muted}'
  status-chip-on-track:
    background: '{colors.status-success-soft-bg}'
    foreground: '{colors.status-success-soft-text}'
    radius: '{rounded.full}'
  status-chip-too-early:
    background: '{colors.brand-cream-soft}'
    foreground: '{colors.brand-ink-muted}'
    radius: '{rounded.full}'
  status-chip-behind-pace:
    background: '{colors.brand-warning-soft}'
    foreground: '{colors.brand-warning-deep}'
    radius: '{rounded.full}'
  subtrack-summary-card:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
    bar-fill: '{colors.brand-blue}'
    bar-track: '{colors.brand-cream-soft}'
    bar-height: '{spacing.progress-bar-height}'
  capacity-bar:
    fill: '{colors.brand-blue}'
    track: '{colors.brand-cream-soft}'
    height: '{spacing.progress-bar-height}'
    no-shortfall-tag: '{components.status-chip-on-track}'
    shortfall-tag: '{components.status-chip-behind-pace}'   # parent / tutor only
  erev-banner:
    background: '{colors.brand-blue-soft}'
    foreground: '{colors.brand-ink}'
    icon: '{colors.brand-blue}'
    radius: '{rounded.card}'
  disabled-action:
    opacity: '0.4'
    label: '{colors.brand-ink-muted}'
  catch-up-card:
    background: '{colors.brand-blue-soft}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
    primary-action: '{components.plus-one-button}'
    secondary-action: outlined-pill
  tutor-mode-bar:
    background: '{colors.settings-profile-badge-tutor-bg}'
    accent: '{colors.brand-warning-deep}'   # icon + edge; 5.77:1 light / 9.23:1 dark
    foreground: '{colors.brand-warning-deep}'
    min-height: '{spacing.touch-target}'
  ground-row:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    drag-handle: '{colors.brand-ink-muted}'
  ground-tag-in-use:
    background: '{colors.brand-cream-soft}'
    foreground: '{colors.brand-ink-muted}'
    radius: '{rounded.tag}'
  ground-tag-chazara:
    background: '{colors.brand-blue-soft}'
    foreground: '{colors.brand-blue}'
    radius: '{rounded.tag}'
  history-event-row:
    border: '{colors.brand-outline}'
    count-text: '{typography.title-medium}'
  date-state-tag-catch-up:
    background: '{colors.brand-coral-soft}'
    foreground: '{colors.brand-ink-2}'
    radius: '{rounded.tag}'
  before-tracking-badge:
    background: '{colors.brand-gold-soft}'
    foreground: '{colors.curriculum-mishna}'
    radius: '{rounded.full}'
  change-history-entry:
    border: '{colors.brand-outline}'
    undone-label: '{colors.brand-ink-muted}'
  talmid-row:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
  per-source-pace-row:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    radius: '{rounded.card}'
    value-text: '{typography.headline-small}'
    caption: '{colors.brand-ink-muted}'
  info-note:
    background: '{colors.brand-blue-soft}'
    icon: '{colors.brand-blue}'
    foreground: '{colors.brand-ink-2}'
    radius: '{rounded.card}'
  nav-rail:
    background: '{colors.brand-cream-card}'
    border: '{colors.brand-outline}'
    width: '{spacing.nav-rail-width}'
    selected-indicator: '{colors.brand-blue-soft}'
    selected-foreground: '{colors.brand-blue}'
---

# Learning Tracker — Sub-tracks · Design Spine

These spines win on conflict with any mock, wireframe, or import. Behaviour lives in [`EXPERIENCE.md`](EXPERIENCE.md); this file owns how Sub-tracks looks.

## Brand & Style

Sub-tracks adds to Learning Tracker without creating a new brand. It inherits the app's current look: calm, friendly Material 3 for Orthodox Jewish families. A boy of about ten ticks off Mishnayos while a parent and rebbe configure his plan. Flat white outlined cards sit on a cool cream canvas. Royal blue carries every action; coral and gold mark streaks and celebration.

Sub-tracks adds a quiet second list of rows under the child's day, a status and occasional amber warning for the parent, and a planned list before shabbos. Nothing in the feature raises its voice at the child. The visual system shows no red or amber "behind" state to him, and no badge implies that outside-source learning counts for less.

Foundation: `AppTheme` (light and dark `ThemeData`, `ThemeMode.system`) and the `AppPalette` ThemeExtension are read through `context.colors`. The frontmatter lists only the tokens this feature uses, each mapped 1:1 to an AppPalette getter; new tokens are flagged **NEW**. Everything else is inherited by name: Material buttons, inputs, dialogs, sheets, snackbars, bottom navigation, profile switcher, viewing-child banner, streak chip, siyum celebration, and the full-screen `SacredTimeLockOverlay`.

Imagery: the feature uses no photography; any illustrated human figure is male.

## Colors

The palette uses the shipping `AppPalette`. Sub-tracks draws a small set of roles from it.

- **Brand blue (`{colors.brand-blue}` #1442B8 / `{colors.brand-blue-dark}` #7CA0FF).** The only action color: +1 pills, *Up to…* text buttons, *Record n mishnayos*, *Save sub-track*, the selected rail item, and the School source chip. 8.4:1 on white; 6.9:1 on the dark card.
- **Blue soft (`{colors.brand-blue-soft}` #E4EBFA / #16233F).** Informational containers that aren't warnings: erev banner, catch-up card, info notes, School-year source chip, chazara tag.
- **Cream canvas / card / recessed (`{colors.brand-cream}`, `{colors.brand-cream-card}`, `{colors.brand-cream-soft}`).** Canvas, card surface, and recessed fills (progress tracks, Home chip, neutral chips). Dark set: #0B0F1A / #151A26 / #1E2532.
- **Outline (`{colors.brand-outline}` #D4DCE8 / #263041).** 1px card borders and dividers. This is the structure in place of shadow.
- **Ink ramp (`{colors.brand-ink}` → `{colors.brand-ink-2}` → `{colors.brand-ink-muted}` → `{colors.brand-ink-soft}`).** Headings, body, secondary text, hints and empty checkbox borders. Muted ink is 5.98:1 on the light card and 6.75:1 on the dark card.
- **Warning amber (`{colors.brand-warning-soft}` fill + `{colors.brand-warning-deep}` text and icons).** Parent- and tutor-facing only: shortfall warning card, *Behind pace* chip, tutor-mode bar, ongoing-source chip. Text **and** icons on the soft fill use deep: 5.6:1 light, 9.84:1 dark. The brighter `brandWarning` (2.99:1 on the soft fill) is not used on these fills. Amber never appears on a child-facing status.
- **Success green (`{colors.status-success-soft-bg}` / `{colors.status-success-soft-text}`).** *On track* and *No shortfall*. 4.55:1 light, 7.67:1 dark.
- **Tri-state (FR-15).** Two existing widgets in `lifetime_folder_styled_widgets.dart` are combined. The read-only lifetime tree node (`LifetimeFolderTreeNode`, :395-425) supplies the state colors, 12% row tint, 20dp depth indent and expand behaviour. The marking row (`LifetimeMarkingScopeRow`, :493-580) supplies the checked / dash / empty tristate checkbox.
  - complete = `{colors.status-success-muted}` (#3BDD87 / #72DEA4), checked box.
  - partial = `{colors.progress-lifetime-partial}` row tint plus the **NEW** `{colors.tristate-partial-accent}` (#FFD26A light / #E6B96A dark) on an indeterminate-dash checkbox.
  - empty = `{colors.progress-lifetime-none-on-light}` row tint (#B8C0CC / #36425A), with an empty box bordered in `{colors.brand-ink-soft}` (4.73:1 light, 5.18:1 dark).
  - The brainstorm's grey box is not adopted.
- **Tutor mode (`{colors.settings-profile-badge-tutor-bg}` fill).** The existing tutor-mode indicator's fill. Its icon, edge and label use `{colors.brand-warning-deep}` (5.77:1 light, 9.23:1 dark). `tutorModeAccent` (#D97706, 2.9:1 on this fill) is not used on it.
- **Catch-up tag (`{colors.brand-coral-soft}`) and Before-tracking badge (`{colors.brand-gold-soft}` + `{colors.curriculum-mishna}`).** Small date-state markers in Mishna history.

Dark mode uses the `-dark` value of every token. The approved dark mocks use exactly these values (canvas #0B0F1A, card #151A26, outline #263041, primary #7CA0FF, ink #EAEEF5).

**Contrast targets.** Text ≥ 4.5:1 and non-text UI ≥ 3:1 against the immediate fill, in both modes. Every load-bearing pair above is verified at the stated ratio. Tri-state row *tints* are decorative (12% alpha). State is carried by the checkbox, the count label ("0 of 8 learnt") and the semantics label.

## Typography

The app's `AppTextStyles` ramp uses Plus Jakarta Sans. Hebrew script (ברכות א:ד, סדר מועד) uses Noto Sans Hebrew at `{typography.hebrew-body-medium}` (one step larger). The existing **Hebrew Terms** setting determines whether a domain term appears in Hebrew script or transliteration. The mocks show both side by side for illustration only.

| Role | Token | Used for |
|---|---|---|
| Screen title | `{typography.app-bar-title}` | Centred app-bar title ("Manage tracks", "School year", "Change history") |
| Card heading | `{typography.title-medium}` | On-track status, catch-up question, sub-track detail header |
| Row title | `{typography.title-small}` | Sub-track row name, ground row, talmid name |
| Position | `{typography.body-medium}` | "Next: Berachos 1:4" |
| Supporting | `{typography.body-small}` | Window, rate, helper text under form fields |
| Section header | `{typography.label-large}` | "Also learning", "Planned for Shabbos", "Ground (in order)", in sentence case |
| Tag / chip | `{typography.label-small}` | Source chips, date-state tags, ground tags |
| Stat numerals | `{typography.headline-small}` | Lifetime report totals, capacity numbers, per-source pace |

Buttons and Material chips use the inherited theme styles. No all-caps text: the uppercase labels in some mocks ("PLANNED FOR SHABBOS") are Stitch styling.

## Layout & Spacing

The theme has no named spacing scale. Sub-tracks uses the 4-based values already in the theme and the mocks. Cards stack `{spacing.3}` apart and sections ("Today" → "Also learning") `{spacing.5}` apart. Phone gutters are `{spacing.gutter-mobile}`. Every interactive element is at least `{spacing.touch-target}` tall.

**Phone.** Single column inside the existing shell: centred app bar, context bars (profile switcher, viewing-child banner, tutor-mode bar), content, and the rounded-top bottom navigation (Dashboard · Learn · Progress · Settings). The up-to picker is a bottom sheet. Forms scroll, with the primary action at the end.

**Tablet.** The shell's destinations move to a left `nav-rail` (`{spacing.nav-rail-width}`, labelled items, same four destinations). Content sits on a 12-column grid with a list-detail split per surface:

| Surface | Tablet composition | Mock |
|---|---|---|
| Learn tab | Today list (7 cols) · Also learning (5 cols) | [`mockups/01-learn-tab-tablet.html`](mockups/01-learn-tab-tablet.html) |
| Up-to picker | Centred dialog, max `{spacing.dialog-max-width}`, over the Learn context | [`mockups/02-up-to-dialog-tablet.html`](mockups/02-up-to-dialog-tablet.html) |
| Dashboard (parent) | Status row (on-track · projected finish · daily target); full-width shortfall card; main track and sub-track summary cards in a grid | [`mockups/03-dashboard-parent-tablet.html`](mockups/03-dashboard-parent-tablet.html) |
| Manage tracks | Track list · selected sub-track detail | [`mockups/04-manage-tracks-tablet.html`](mockups/04-manage-tracks-tablet.html) |
| Sub-track forms | Form (≤ `{spacing.form-max-width}`) · summary panel | [`mockups/05-new-school-year-tablet.html`](mockups/05-new-school-year-tablet.html), [`mockups/06-new-ongoing-tablet.html`](mockups/06-new-ongoing-tablet.html) |
| Sub-track detail | Detail (6 cols) · ground picker (6 cols) | [`mockups/07-subtrack-detail-tablet.html`](mockups/07-subtrack-detail-tablet.html) |
| Ground picker | Corpus tree · "Selected to add" panel | [`mockups/08-ground-picker-tablet.html`](mockups/08-ground-picker-tablet.html) |
| Erev planned view | Planned list · sub-track rows | Spine-only (no tablet mock; phone mock [`mockups/09-erev-mobile.html`](mockups/09-erev-mobile.html)) |
| Catch-up | Catch-up card + Adjust list · today | [`mockups/10-catch-up-tablet.html`](mockups/10-catch-up-tablet.html) |
| Talmidim | Talmid list (5 cols) · selected learner (7 cols) | [`mockups/11-tutor-talmidim-tablet.html`](mockups/11-tutor-talmidim-tablet.html) |
| Change history | Timeline · change details | [`mockups/12-change-history-tablet.html`](mockups/12-change-history-tablet.html) |
| Mishna history | Summary + per-source breakdown · event list | [`mockups/13-mishna-history-tablet.html`](mockups/13-mishna-history-tablet.html) |
| Lifetime report | Totals + by-source + per-source pace · school-year groups | [`mockups/14-lifetime-report-tablet.html`](mockups/14-lifetime-report-tablet.html) |

Breakpoints are `[ASSUMPTION]`; see EXPERIENCE.md § Responsive & Platform.

## Elevation & Depth

The feature is flat. Cards, rows, chips, buttons, app bar and navigation all sit at elevation 0. Hierarchy comes from `{colors.brand-outline}` borders and tone steps (canvas → card → recessed). The only shadows are ones the app already has: the bottom-navigation card's subtle shadow and the modal barrier behind sheets and dialogs. Sub-tracks adds none.

**Don't use `StatCard`** (`core/widgets/stat_card.dart`) for Sub-tracks cards as it stands. It paints a box shadow (blur 14, offset 0,6) and defaults to radius 22. Use the theme `Card` (flat, 18dp, 1px outline), or give `StatCard` a flat variant with no shadow and `{rounded.card}` before reusing it. The `shadow-sm` in several Stitch mocks is renderer drift.

## Shapes

The feature inherits the app's radii: cards `{rounded.card}` (18), pill buttons `{rounded.full}`, inputs `{rounded.input}` (12), Material chips `{rounded.chip}` (20), checkboxes `{rounded.checkbox}` (4), sheets `{rounded.sheet-top}` (24 top), shared dialog `{rounded.app-dialog}` (28). It adds one: **NEW** `{rounded.tag}` (6) for small non-interactive tags (source, date-state, ground). This keeps tags visibly distinct from the pill-shaped controls you can tap.

## Components

Anything not listed here is the existing app component, unchanged. Behaviour for every component below is in EXPERIENCE.md § Component Patterns under the same name.

- **Sub-track row.** Outlined card (`subtrack-row`). Leading source icon. Name in `{typography.title-small}`. "Next: Berachos 1:4" in `{typography.body-medium}`, with the Hebrew reference beneath when Hebrew Terms is on. Trailing: *Up to…* text button and **+1 button** pill. Rows group under an "Also learning" section header with a count ("2 sub-tracks"). In the groundless state, the position line is replaced by helper text and both actions render as `Disabled action`. No source picker, rate or pace badge. → [`mockups/01-learn-tab-mobile.html`](mockups/01-learn-tab-mobile.html), [`mockups/01-learn-tab-dark.html`](mockups/01-learn-tab-dark.html)
- **+1 button.** Filled `{colors.brand-blue}` pill labelled "+1" (sub-track rows) or "Mark +1" (main-track list), 48dp high.
- **Up to… button.** `{colors.brand-blue}` text button, `{rounded.text-button}`, 48dp touch height.
- **Up-to picker.** Phone: bottom sheet, `{rounded.sheet-top}`. Tablet: centred dialog, `{rounded.app-dialog}`.
  - Header: title "School · up to…" with close; subtitle "Tap the last mishna you learnt".
  - Rows: mishnayos in track order, each with a checkbox and a trailing state label (*Included* / *Skipped* / *Next up*). The tapped target row is highlighted in `{colors.brand-blue-soft}`.
  - Footer: *Cancel* (text) and *Record n mishnayos* (primary pill, live count).
  - → [`mockups/02-up-to-sheet-mobile.html`](mockups/02-up-to-sheet-mobile.html), [`mockups/02-up-to-sheet-dark.html`](mockups/02-up-to-sheet-dark.html), [`mockups/02-up-to-dialog-tablet.html`](mockups/02-up-to-dialog-tablet.html)
- **Tri-state row.** The lifetime tree node's look combined with the marking row's checkbox (see Colors), using `tristate-row-complete` / `-partial` / `-empty`. 12% state tint, tristate checkbox, `{spacing.tree-indent}` per depth, expand chevron on non-leaf nodes, count text ("3/9", "3 of 5 learnt"). A legend strip "Complete · Partial · Empty" sits at the foot of the ground picker.
- **Free-tick row.** The corpus browser (existing Browse) shows each node as a `Tri-state row`. Long-press offers "Tick up to here". A batch confirms through a `showAppDialog` sheet with three parts: a source radio list (Home default, then each active sub-track, then *Before tracking*), a date field (defaults to today), and a *Record n mishnayos* pill. `[ASSUMPTION]` No mock.
- **Source chip.** `{rounded.tag}` tag with icon and label, coloured by source type: Home = `source-chip-home`, school-year sub-track = `source-chip-school-year`, ongoing sub-track = `source-chip-ongoing`. The label is the sub-track's name. `[ASSUMPTION]` Colour keys off source *type*, so all ongoing sub-tracks share amber. → [`mockups/13-mishna-history-mobile.html`](mockups/13-mishna-history-mobile.html)
- **Shortfall warning card.** `shortfall-card`: warning icon in a soft circle, message, trailing text action *View School →*. Full-width, directly under the on-track card. Parent and tutor only. → [`mockups/03-dashboard-parent-mobile.html`](mockups/03-dashboard-parent-mobile.html), [`mockups/03-dashboard-parent-dark.html`](mockups/03-dashboard-parent-dark.html)
- **On-track card.** `on-track-card`, parent and tutor only.
  - Status line with icon: *On track* (success text), *Behind pace* (warning deep) or *Too early to tell* (muted ink).
  - "Projected finish: 14 Mar 2029 · deadline Elul 5789".
  - "Daily target: 3 mishnayos/day".
- **Status chip.** Pill chips for the talmidim list: `status-chip-on-track`, `status-chip-too-early`, `status-chip-behind-pace`.
- **Sub-track summary card.** One Dashboard card per active sub-track: name, "Next: …", ticked count, and a `{spacing.progress-bar-height}` bar drawn with the existing `AnimatedProgressBar` (600ms ease-in-out). Section header "Sub-tracks (2)" with a *Manage* text action.
- **Capacity bar.** On sub-track detail, for every role. "Capacity vs Path" header, numerals "350 / 390" and a 6dp bar, with the caption "Remaining path: 350 · Total capacity: 390". A trailing tag shows *No shortfall* (success) or, for parent and tutor only, the shortfall count (warning). The child sees the bar and caption with no tag. → [`mockups/07-subtrack-detail-mobile.html`](mockups/07-subtrack-detail-mobile.html), [`mockups/07-subtrack-detail-dark.html`](mockups/07-subtrack-detail-dark.html)
- **Ground row.** Outlined row in "Ground (in order)":
  - Leading drag handle and tri-state checkbox.
  - Name + Hebrew, then "3 of 5 learnt · Mishnayos 1:1 – 1:5".
  - Trailing chevron.
  - Ground learnt elsewhere shows complete with the caption "learnt at home" (or the other source's name).
- **Add next year.** Outlined pill at the foot of a school-year sub-track detail: "Add next year (2027–28)". It renders as `Disabled action` when that year is already used.
- **Delete sub-track confirm.** Opens from the detail's ⋮ → *Delete track* as the existing `showAppConfirmDialog`: warning icon, title, message, destructive confirm in the theme's error colour, *Cancel*. No new styling.
- **Ground picker.** Full-screen on phone.
  - Top: search field, then a filter row ("Showing: All Sederim", "Available only", Hebrew-only toggle).
  - Body: corpus tree of `Tri-state row`s (seder › masechta › perek), with tags `ground-tag-in-use` ("Rebbe · In use") and `ground-tag-chazara` ("Chazara").
  - Sticky footer: *Reset changes* (text), *Add 3 perakim to School* (primary pill), and the helper "They'll leave the home schedule while School holds them."
  - → [`mockups/08-ground-picker-mobile.html`](mockups/08-ground-picker-mobile.html), [`mockups/08-ground-picker-dark.html`](mockups/08-ground-picker-dark.html)
- **Sub-track form.** Standard filled inputs (`{rounded.input}`).
  - Rate: a stepper with −/+ round buttons around a numeral and helper text ("~2 mishnayos / school day").
  - Weeks per year: numeric field with helper text.
  - Switch rows: *Learns on shabbos / yom tov*; on the ongoing form, also *Not learning during bein hazmanim*.
  - An `Info note`, then the primary *Save sub-track* pill.
  - → [`mockups/05-new-school-year-mobile.html`](mockups/05-new-school-year-mobile.html), [`mockups/05-new-school-year-dark.html`](mockups/05-new-school-year-dark.html), [`mockups/06-new-ongoing-mobile.html`](mockups/06-new-ongoing-mobile.html), [`mockups/06-new-ongoing-dark.html`](mockups/06-new-ongoing-dark.html)
- **Academic-year picker.** Horizontal row of selectable year chips (`{rounded.chip}`), each with a small state label: *Used* (`Disabled action`), *Active*, *Open*.
- **Info note.** `info-note`: info icon plus one sentence on `{colors.brand-blue-soft}`. Used for form helpers, "You see only learners whose parents gave you access." and the onboarding mention.
- **Onboarding mention.** A single `Info note` on one existing onboarding step. No button, no link styling, no illustration.
- **Erev banner + planned list.** `erev-banner` shows the Shabbos label in English and Hebrew ("Shabbos Kodesh · שבת קודש") and the lock time. Below it, the "Planned for Shabbos" section header introduces the main-track mishnayos planned for the locked day(s), rendered with the **live** main-track row styling (checkboxes and +1 enabled). The "Also learning" rows are unchanged and live. → [`mockups/09-erev-mobile.html`](mockups/09-erev-mobile.html). The mock shows the planned rows as a preview without checkboxes; this specification (live rows) wins. No dark or tablet erev mock exists.
- **Lock overlay.** The existing full-screen `SacredTimeLockOverlay`, unchanged: an opaque `sacredTimeLockShabbosBg` / `sacredTimeLockYomTovBg` / `sacredTimeLockShabbosYomTovBg` / `sacredTimeLockYomKippurBg` surface, a large white icon and a greeting. It covers the whole app during the lock. Sub-tracks adds nothing to it.
- **Disabled action.** `disabled-action`: 40% opacity, no ripple, label in `{colors.brand-ink-muted}`. Used only for groundless-row actions (child), used academic years, and *Add next year* when the next year is already used. The control stays in place at full size.
- **Catch-up card.** `catch-up-card` at the top of the Learn tab.
  - Calendar icon, then the question in `{typography.title-medium}` and an availability caption.
  - Actions: *Yes, all of it* (primary pill) and *Adjust…* (outlined pill).
  - *Adjust…* expands in place into per-source groups ("Home · Main track", "Rebbe (learns on shabbos)"). Each group has an *Up to…* action and individually checkable rows; the expanded panel closes with a *Record n mishnayos* pill.
  - → [`mockups/10-catch-up-mobile.html`](mockups/10-catch-up-mobile.html), [`mockups/10-catch-up-dark.html`](mockups/10-catch-up-dark.html)
- **Tutor-mode bar.** The existing tutor-mode indicator, recoloured for contrast (`tutor-mode-bar`): "Tutor mode · Rav Cohen" with a *Switch* action, full-width under the app bar.
- **Talmid row.** Outlined card: initials avatar, name, status chip, and "Rebbe: next Beitzah 3:1" (or "Rebbe: no ground yet" with an *Add ground* action), plus chevron. The list ends with an `Info note`: "You see only learners whose parents gave you access." → [`mockups/11-tutor-talmidim-mobile.html`](mockups/11-tutor-talmidim-mobile.html), [`mockups/11-tutor-talmidim-dark.html`](mockups/11-tutor-talmidim-dark.html)
- **Revoke tutor.** The existing Manage tutors screen and its revoke action with confirm dialog, unchanged.
- **Change-history entry.** A **NEW** parent-scoped timeline. The existing `TutorAuditLogScreen` is keyed by a single tutor grant and isn't reused as-is.
  - Day header: "Today · Thu, 20 Feb · 4 updates".
  - Entry: actor avatar, name, role tag and time; a sentence with the Hebrew term inline; trailing *Undo* text button.
  - Undone entries carry an *Undone* tag in `{colors.brand-ink-muted}`, and the undo appears as its own entry.
  - A bell icon marks entries that notified the parent.
  - Filter chips: All · Tutor · Parent · Learning.
  - → [`mockups/12-change-history-mobile.html`](mockups/12-change-history-mobile.html), [`mockups/12-change-history-dark.html`](mockups/12-change-history-dark.html)
- **History event row.** Numbered entries, newest first.
  - Each entry: date (or *Before tracking* badge), source chip, date-state tag (*catch-up*), repeat tag (*chazara*).
  - Summary header: "Learnt · נלמד" and "5 times learnt".
  - Footer `Info note`: "Repeats never add to goal progress — they're kept here as your record."
  - → [`mockups/13-mishna-history-mobile.html`](mockups/13-mishna-history-mobile.html), [`mockups/13-mishna-history-dark.html`](mockups/13-mishna-history-dark.html)
- **Per-source pace row.** Lifetime report "Per-source pace" section, one `per-source-pace-row` per sub-track: source chip, measured value in `{typography.headline-small}` ("9.6 / week"), and the caption "10 / week estimate". The window label is "Last 30 days". The mock's "On pace" / "Steady" labels are not adopted pending the FR-32 metric decision.
- **School-year group row.** Lifetime report rows, one expandable row per same-named sub-track ("School · 640 mishnayos"). Each expands to one line per academic year ("2024–25 · 210 mishnayos", "2026–27 · In progress · 180"). Totals use `{typography.headline-small}`. *Export PDF* is a primary pill. → [`mockups/14-lifetime-report-mobile.html`](mockups/14-lifetime-report-mobile.html), [`mockups/14-lifetime-report-dark.html`](mockups/14-lifetime-report-dark.html)
- **Ended sub-tracks group.** Collapsed row at the foot of the Manage tracks sub-track list, "Ended sub-tracks (1)". It expands to muted rows ("School 2025–26 · Ended Jul 2026"). → [`mockups/04-manage-tracks-mobile.html`](mockups/04-manage-tracks-mobile.html), [`mockups/04-manage-tracks-dark.html`](mockups/04-manage-tracks-dark.html)
- **Navigation rail.** Tablet only (`nav-rail`). Card-surface column with a right border and labelled destinations (Dashboard · Learn · Progress · Settings). The selected item sits on `{colors.brand-blue-soft}` with icon and label in `{colors.brand-blue}`.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Name the app **Learning Tracker** everywhere | Use "Mishnayos Tracker" or any other title from the Stitch mocks |
| Map every colour to an AppPalette getter; add a getter only where this file marks **NEW** | Hard-code hex values or introduce Stitch's Material-baseline palette (#002c8e, #ab350b …) |
| Keep every surface flat: elevation 0, 1px outline, tone steps | Add card shadows or gradients, or reuse `StatCard` without a flat variant |
| Combine the lifetime-tree colours with the marking-row tristate checkbox for every corpus node | Invent a new partial style or adopt the brainstorm's grey box |
| Keep amber, shortfall and *Behind pace* on parent and tutor surfaces only | Show *Behind pace*, off-track, shortfall or any red/amber status to the child |
| Put exactly two actions on a sub-track row: *Up to…* and **+1** | Add a source picker, a "Cheder / School track" badge, a rate or a pace badge to a sub-track row |
| Keep erev controls live, and cover the whole app with the existing lock overlay during the lock | Show a readable, greyed-out or partly usable app during the lock |
| Use `brand-warning-deep` for amber text and icons on soft fills | Use `brandWarning` or `tutorModeAccent` on their soft fills (below 3:1) |
| Illustrate people, where needed at all, as male figures | Use photography or female figures anywhere in the feature |
| Treat mock counts and names ("Class 5B", "Yeshiva Darchei Torah", "Rabbi Stern") as illustrative | Carry invented copy, tips, projections or institution names from mocks into the build |
