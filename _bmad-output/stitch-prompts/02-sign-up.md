# Sign Up Screen - Stitch Prompt

## Screen Purpose
New user registration screen for Learning Tracker app.

## Device Type
Mobile (Android)

## Design System
Material Design 3, Dark Mode

## Detailed Prompt

Create a mobile sign-up screen for a Torah learning tracking app with these specifications:

**Theme & Colors:**
- Dark mode background (#121212)
- Primary accent color: bright green (#13ec13)
- Surface color for cards: #1E1E1E
- Text colors: white primary, #B0B0B0 secondary
- Error states: red-400 (#EF5350)

**Layout (Top to Bottom):**

1. **Header**
   - Back button (top-left, green icon)
   - Screen title: "Create Account"
   - Subtitle: "Join thousands learning Torah daily"
   - Top padding: 16dp

2. **Registration Form**
   - Full Name field:
     - Label: "Full Name"
     - Placeholder: "Moshe Cohen"
     - Material 3 outlined text field
     - Green outline when focused (#13ec13)

   - Email field:
     - Label: "Email"
     - Placeholder: "your@email.com"
     - Material 3 outlined text field
     - Email keyboard type
     - Green outline when focused

   - Password field:
     - Label: "Password"
     - Placeholder: "At least 8 characters"
     - Show/hide toggle
     - Material 3 outlined text field
     - Helper text: "Use letters, numbers, and symbols"
     - Password strength indicator (weak/medium/strong)

   - Confirm Password field:
     - Label: "Confirm Password"
     - Placeholder: "Re-enter password"
     - Show/hide toggle
     - Material 3 outlined text field
     - Validation check icon when matches

3. **Terms & Conditions**
   - Checkbox with text: "I agree to the Terms of Service and Privacy Policy"
   - Clickable links in green (#13ec13)
   - Required before sign up enabled

4. **Sign Up Button**
   - Full width elevated button
   - Background: bright green (#13ec13)
   - Text: "Create Account" in black bold text
   - Height: 48dp
   - Rounded corners (24dp radius)
   - Disabled state (gray) until form valid
   - 16dp horizontal margin

5. **Alternative Sign Up (Optional)**
   - Divider with "OR" text
   - Google Sign Up button (white outline, Google logo)

6. **Sign In Link (Bottom)**
   - Centered text: "Already have an account? Sign In"
   - "Sign In" in green (#13ec13)
   - Bottom padding: 24dp

**Spacing & Measurements:**
- Form fields: 16dp vertical spacing
- Side margins: 16dp
- Header to form: 24dp
- Form to button: 32dp
- All touch targets: minimum 48dp

**Typography:**
- Screen title: 24sp, bold
- Subtitle: 14sp, regular, #B0B0B0
- Input labels: 14sp
- Input text: 16sp
- Helper text: 12sp, #B0B0B0
- Button text: 16sp, medium weight
- Terms text: 12sp
- Sign in link: 14sp

**Validation States:**
- Error: red outline (#EF5350), error message below field
- Success: green checkmark icon on right
- Focus: green outline (#13ec13)
- Disabled: gray (#757575)

**Cultural Considerations:**
- Clean, text-focused design
- No decorative imagery
- Professional Torah learning aesthetic

**Accessibility:**
- All form fields properly labeled
- Error messages clearly associated with fields
- Password strength communicated visually and textually
- Minimum 48dp touch targets
