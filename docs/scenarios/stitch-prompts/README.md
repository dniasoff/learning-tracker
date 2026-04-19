# Stitch UI Prompts for Learning Tracker

This folder contains comprehensive Stitch design prompts for all screens in the Learning Tracker app.

## About These Prompts

Due to a precision bug in the Stitch MCP API (project IDs exceed JavaScript safe integer limit), these prompts are provided as individual files for manual use in Stitch.

## How to Use

1. Visit [stitch.withgoogle.com](https://stitch.withgoogle.com)
2. Open or create your project
3. Copy the prompt from the relevant file below
4. Paste into Stitch's prompt field
5. Select "MOBILE" as device type
6. Generate the design

## Design System Overview

All screens use:
- **Material Design 3** foundation
- **Dark Mode** theme (#121212 background, #1E1E1E cards)
- **Green accent** (#13ec13) - primary actions, highlights
- **Noto Sans Hebrew** font for Hebrew text (RTL support)
- **Curriculum colors**: Amber (Mishnayos), Blue (Bavli), Cyan (Yerushalmi), Burgundy (Mishna Berurah), Green (Chumash)
- **Cultural requirement**: Male-only character illustrations (Orthodox Jewish sensitivity)

## Screen Prompts

### Authentication (2 screens)
1. **[01-sign-in.md](01-sign-in.md)** - User sign-in with email/password
2. **[02-sign-up.md](02-sign-up.md)** - New user registration

### Onboarding Flow (3 screens)
3. **[03-mode-selection.md](03-mode-selection.md)** - Choose learning mode (Self-Learner/Parent/Tutor)
4. **[04-curriculum-selection.md](04-curriculum-selection.md)** - Select Torah curricula to learn
5. **[05-goal-setup.md](05-goal-setup.md)** - Set learning goals and completion targets

### Main Application (3 screens)
6. **[06-dashboard.md](06-dashboard.md)** - Main home screen with today's tasks and progress
7. **[07-daily-tasks.md](07-daily-tasks.md)** - Detailed daily learning task view
8. **[08-content-browser.md](08-content-browser.md)** - Browse Torah content by curriculum

### Learning Screens (4 screens)
9. **[09-learning-screen.md](09-learning-screen.md)** - Main reading/learning interface
10. **[10-mark-completion-bulk.md](10-mark-completion-bulk.md)** - Bulk mark multiple pages complete
11. **[11-learning-history.md](11-learning-history.md)** - Complete learning history with filters
12. **[12-progress-charts.md](12-progress-charts.md)** - Visual analytics and progress charts

### Parent Mode (2 screens)
13. **[13-parent-dashboard.md](13-parent-dashboard.md)** - Monitor children's learning progress
14. **[14-parent-rewards.md](14-parent-rewards.md)** - Manage reward points and redemptions

### Tutor Mode (1 screen)
15. **[15-tutor-dashboard.md](15-tutor-dashboard.md)** - Manage students and assign tasks

### Settings & Configuration (2 screens)
16. **[16-settings.md](16-settings.md)** - App preferences and account settings
17. **[17-stage-editor.md](17-stage-editor.md)** - Advanced learning stage customization

## Screen Priority Order

### Phase 1: Core Functionality (MVP)
Generate these first for basic app functionality:
1. Sign In (01)
2. Dashboard (06)
3. Daily Tasks (07)
4. Learning Screen (09)
5. Settings (16)

### Phase 2: Onboarding & Discovery
6. Sign Up (02)
7. Mode Selection (03)
8. Curriculum Selection (04)
9. Goal Setup (05)
10. Content Browser (08)

### Phase 3: Enhanced Features
11. Learning History (11)
12. Progress Charts (12)
13. Bulk Mark (10)

### Phase 4: Multi-User Modes
14. Parent Dashboard (13)
15. Parent Rewards (14)
16. Tutor Dashboard (15)

### Phase 5: Advanced Configuration
17. Stage Editor (17)

## Design Specifications Summary

### Colors
```
Background: #121212
Surface/Cards: #1E1E1E
Primary Accent: #13ec13 (bright green)
Text Primary: #FFFFFF
Text Secondary: #B0B0B0
Dividers: #2E2E2E

Curriculum Colors:
- Mishnayos: Amber (#FF8F00 light, #FFD54F dark)
- Bavli: Blue (#1565C0 light, #42A5F5 dark)
- Yerushalmi: Cyan (#00838F light, #4DD0E1 dark)
- Mishna Berurah: Burgundy (#6A1B29 light, #AD1E3D dark)
- Chumash: Green (#2E7D32 light, #66BB6A dark)

Status Colors:
- Success: #13ec13 (green)
- Warning: #FFB300 (amber)
- Error: #EF5350 (red)
```

### Typography Scale
```
Display/Hero: 28-36sp, bold
Title: 20-24sp, bold
Headline: 18sp, bold
Body Large: 16sp, regular/medium
Body: 14sp, regular
Caption: 12sp, regular
Label: 11sp, uppercase
```

### Spacing
```
Micro: 4dp
Small: 8dp
Medium: 12dp
Default: 16dp
Large: 24dp
XLarge: 32dp
XXLarge: 48dp
```

### Component Specs
- **Cards**: 12dp corner radius, 2dp elevation, #1E1E1E background
- **Buttons**: 48dp height, 24dp corner radius (pill shape)
- **Touch Targets**: Minimum 48dp x 48dp
- **Icons**: 24dp standard, 32-56dp featured
- **Profile Pictures**: 32dp (small), 56dp (medium), 64dp (large)
- **Progress Bars**: 4-8dp height, rounded ends
- **Input Fields**: Material 3 outlined style, green focus

## Total Screens: 17

Each prompt includes:
- Screen purpose and context
- Complete layout specifications (top to bottom)
- Exact measurements and spacing
- Color specifications
- Typography details
- Interactive states
- Empty states
- Loading states
- Accessibility considerations
- Cultural requirements

## Related Documentation

For implementation details, see:

- [Component Inventory](../../component-inventory.md) — shipped widgets/screens catalogue
- [UX Patterns Quick Reference](../../planning/ux-patterns-quick-reference.md)
- [Architecture (current state)](../../architecture.md)
- [PRD (historical)](../../planning/prd.md)
- [Developer Handbook](../../developer-handbook.md) for domain context

> **Note:** `component-specifications.md`, `ux-design-specification.md`, and `development-handoff.md` — referenced in earlier versions of this file — are archived under [`docs/_archive/superseded/`](../../_archive/superseded/). Treat them as historical records only.

## Notes

- All screens support RTL (Right-to-Left) for Hebrew text
- Dark mode is the primary theme
- Material Design 3 components throughout
- Consistent green (#13ec13) for primary actions
- Each curriculum has its own color identity
- Male-only character illustrations per Orthodox Jewish requirements

## Stitch Project

These designs are intended for Stitch project:
- Project ID: 8315119209652358525
- Project URL: https://stitch.withgoogle.com/projects/8315119209652358525

---

**Generated**: February 8, 2026
**For**: Learning Tracker - Torah Learning Progress Tracking App
**Framework**: Flutter/Dart for Android
**Design System**: Material Design 3
