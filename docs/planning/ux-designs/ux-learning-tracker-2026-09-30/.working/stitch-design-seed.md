# Learning Tracker — current visual identity (Stitch seed)

Working artifact, not the DESIGN.md spine. Every value below is lifted from the shipping Flutter app
(`learning_tracker/lib/core/theme/app_theme.dart`, `app_palette.dart`, `text_styles.dart`) so new
Sub-tracks screens match the existing product. Light mode is the reference for mocks.

## Brand & style
A calm, friendly Torah-learning tracker for Orthodox Jewish families — a child (about 10) ticks off
Mishnayos; a parent and a rebbe/tutor configure. Clean Material 3, flat (zero elevation), cards defined
by a 1px outline on a cool cream canvas. Warm coral and gold are accents for streaks and celebration only.
Any illustrated people are male only. No photography.

## Colors (light)
- Primary royal blue `#1442B8`; bright `#2B5FD9`; deep `#0E3392`; primary container `#E4EBFA`
- Secondary coral `#E05A30` (streaks, highlights); soft `#FDE9E2`
- Success / tertiary green `#4F7A28`; soft `#E3EDD3`
- Warning amber `#C77A12`; soft `#FBF0DC`
- Error `#C0362C`; soft `#FBE9E7`
- Canvas `#F7F8FB`; card surface `#FFFFFF`; recessed surface `#EFF2F7`
- Outline `#D4DCE8`; muted outline `#C7D0DE`
- Ink `#101828` (headings); body ink `#2B3444`; muted ink `#5A6474`; soft ink `#6A7484`
- Mishnayos curriculum identity green `#277B3C`
- Tri-state progress (corpus nodes): complete `#3BDD87` green; partial `#FFD26A` amber with an
  indeterminate dash checkbox; empty `#B8C0CC` muted. Row backgrounds use the state colour at 12% alpha.
- Streak active `#69F0AE`; siyum / trophy gold `#FFC94A`
- Tutor-mode accent `#D97706`; child-view accent `#047857`

## Typography
Plus Jakarta Sans for all Latin text; Noto Sans Hebrew for Hebrew terms (משנה, מסכת, פרק, סדר).
Headline 32/28/24 bold; title 22/18/16 semibold; body 16/14/12 regular; label 14/12/11 medium.
App-bar title 18 bold, centred. Buttons 15 semibold.

## Shape & elevation
Cards 18px radius, 1px outline, no shadow. Buttons fully rounded pills (30px). Inputs filled, 12px radius.
Chips 20px. Checkboxes 4px. Dialogs 16px (shared app dialog 28px). Bottom sheets 24px top radius.
Snackbars floating, 12px. Bottom navigation: rounded-top 28px card with a subtle shadow; four tabs —
Dashboard, Learn, Progress, Settings. Everything else flat.

## Components
- Primary action: filled royal-blue pill. Secondary: outlined pill. Tertiary: text button.
- List rows sit inside outlined white cards on the cream canvas.
- Progress bars: 6px pill track, animated fill.
- Shell context bars above content: profile switcher; "viewing child" banner in parent mode;
  tutor-mode indicator in the tutor accent.
