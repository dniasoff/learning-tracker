# Editorial polish review

## Changelog

- **DESIGN.md — Brand & Style:** tightened the brand, child-facing status, foundation, and imagery prose.
- **DESIGN.md — Colors:** clarified the palette description; token values and color decisions are unchanged.
- **DESIGN.md — Typography:** tightened the font and Hebrew Terms description.
- **DESIGN.md — Typography, Layout & Spacing, Elevation & Depth, Shapes, Components, Do's and Don'ts:** reviewed; section order, tables, and content remain as specified.
- **EXPERIENCE.md — Foundation:** shortened the governing-principle prose.
- **EXPERIENCE.md — Component Patterns and State Patterns:** standardized references to a track's current position.
- **EXPERIENCE.md — State Patterns:** clarified the rejected-sync explanation.
- **EXPERIENCE.md — Interaction Primitives:** clarified +1 terminology and combined the short banned-affordance list.
- **EXPERIENCE.md — Inspiration & Anti-patterns:** phrased rejected directions as current decisions.
- **EXPERIENCE.md — Information Architecture, Roles & Visibility, Voice and Tone, Shabbos & Yom Tov, Accessibility Floor, Responsive & Platform, Key Flows, Open Questions:** reviewed; required section set and order retained. No copy strings, decisions, requirements, IDs, assumptions, deviation notes, questions, or mock links changed.

## Verification

- YAML frontmatter: both files parsed with `yaml.safe_load`.
- Token references: 188 checked against DESIGN.md frontmatter; 0 unresolved.
- Mock links: 101 checked; 0 missing.
- Section order: DESIGN.md body headings and EXPERIENCE.md section set/order match the requested structure.
- Historical phrasing: no remaining unquoted “previously,” “used to,” or “no longer” phrasing; the one quoted “no longer exists” assumption copy string is preserved verbatim.
