# Visual direction exploration — Stage 3

**Status:** Approved by user on 2026-11-13: A + C hybrid is the main experience; B is the dark theme.  
**Goal:** Premium, timeless and intimate. Product is a journal, not a dashboard.

## Shared design rules

- Writing and reading are visually prioritized over decorative components.
- Typographic hierarchy: editorial serif for select headings, highly readable body, clear functional sans UI labels.
- Stable spacing, strong contrast, accessible sizes, responsive layouts and comfortable line length.
- Modal transitions are subtle and reduce-motion compatible; avoid particles, excessive animations, and unnecessary sounds.
- Interface copy is quiet, plain and respectful; never emotionalize or infer journal content without consent.
- Entry pages remain editable and exportable regardless of visual theme.

## Option A — Still Pages

**Mood:** Warm ivory, ink charcoal, restrained linen textures.  
**Distinctive idea:** A refined contemporary notebook that feels excellent for 2,000-word entries.
- Warm paper background and carefully spaced text.
- Serif display titles, readable body text, unobtrusive controls.
- Delicate date/navigation indicators; image blocks blend into the entry.
- Calendar and library resemble a small literary collection.
**Strengths:** Focus, timelessness, accessibility, scalable tablet layouts.
**Risk:** Could look generic if the layout and proportions are not exceptional.

## Option B — Midnight Archive

**Mood:** Graphite, slate, soft silver, restrained amber accents.  
**Distinctive idea:** Quiet, cinematic nighttime reflection, but never a video-player aesthetic.
- Dark writing canvas with measured contrast, unobtrusive toolbar.
- Fine lines and editorial cards for collections and archived memories.
- Subtle depth for navigation and entry transitions.
**Strengths:** Distinct premium atmosphere, inviting nighttime writing.
**Risk:** Long-form reading fatigue if type, contrast and spacing are mishandled; avoid gold overload.

## Option C — Memory Atelier

**Mood:** Warm stone, desaturated sage, soft personal photography, quiet bookbinding motifs.  
**Distinctive idea:** Reading the journal feels like opening a carefully curated life scrapbook.
- Writing mode stays simple; gallery/memory mode can use flexible photo-led layouts.
- Photographs and dates serve as navigational anchors rather than decorative wallpaper.
- A cohesive grid system prevents scrapbook-style visual chaos.
**Strengths:** Emotional recall and distinct identity.
**Risk:** May overwhelm people who primarily write text; gallery styling must be isolated from editor.

## Evaluation criteria (1–5, based on future user test)

1. Writing focus and comfort after long reading.
2. First-entry clarity and tap count.
3. Low-end Android performance potential.
4. Tablet adaptation.
5. Light/dark contrast and accessibility.
6. Emotional appeal without gimmicks.
7. Distinguishability from existing journal products.
8. Feasibility with original assets and offline-first architecture.

## Decision: APPROVED (2026-11-13)

**A Still Pages = editor/reader foundation. C Memory Atelier = media-led memory library. B Midnight Archive = palette/theme variant with the exact same navigation and interaction logic.** The consumer brand name, logo design, and final device-specific screens remain unapproved. The concrete design system, screen inventory, error states, and UX validation requirements are now defined in DESIGN_SYSTEM_V1.md, SCREEN_SPECIFICATION_V1.md, INTERACTION_CONTRACTS_V1.md and UX_VALIDATION_MATRIX.md. Exploratory generated visuals are **not** app implementation or evidence of functional behavior.
