# Sign In Screen - Stitch Prompt

## Screen Purpose
Authentication screen for existing users to sign in to Learning Tracker app.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile sign-in screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent color: bright green (#13ec13)
- Surface color for cards: #1E1E1E
- Text colors: white primary, #B0B0B0 secondary
- Error state: red-400 (#EF5350)

**Layout (Top to Bottom):**

1. **App Logo/Branding (Top Third)**
   - Centered Learning Tracker logo or app name
   - Subtitle: "Track Your Torah Learning Journey"
   - Use Noto Sans Hebrew font family

2. **Sign In Form (Middle)**
   - Email input field:
     - Label: "Email"
     - Placeholder: "your@email.com"
     - Material 3 outlined text field style
     - Green outline when focused (#13ec13)
     - Full width with 16dp horizontal padding

   - Password input field:
     - Label: "Password"
     - Placeholder: "••••••••"
     - Show/hide password toggle icon
     - Material 3 outlined text field style
     - Green outline when focused (#13ec13)
     - Full width with 16dp horizontal padding

   - Forgot Password link:
     - Right-aligned below password field
     - Green text (#13ec13)
     - Small text (14sp)

3. **Sign In Button**
   - Full width elevated button
   - Background: bright green (#13ec13)
   - Text: "Sign In" in black bold text
   - Height: 48dp
   - Rounded corners (24dp radius)
   - 16dp horizontal margin

4. **Alternative Sign In (Optional)**
   - Divider with "OR" text
   - Google Sign In button (white outline, Google logo)

5. **Sign Up Link (Bottom)**
   - Centered text: "Don't have an account? Sign Up"
   - "Sign Up" in green (#13ec13)
   - Bottom padding: 24dp

**Spacing & Measurements:**
- All form elements: 16dp vertical spacing between
- Side margins: 16dp
- Top padding from logo to form: 48dp
- Material elevation for text fields: 0dp (outlined style)
- Button elevation: 2dp

**Typography:**
- App title: 28sp, bold
- Subtitle: 16sp, regular
- Input labels: 14sp
- Input text: 16sp
- Button text: 16sp, medium weight
- Sign up link: 14sp

**Cultural Considerations:**
- Avoid decorative illustrations
- If any character illustrations are needed, use male figures only (Orthodox Jewish sensitivity)
- Clean, professional aesthetic

**Accessibility:**
- All interactive elements minimum 48dp touch target
- Sufficient color contrast for dark mode
- Clear focus states with green accent
