# Navin Journal — visual identity exploration (Stage 3)

**Status:** On 2026-11-13, user selected **01 — Folded Page** as Navin Journal's visual mark. Consumer-facing **name, final platform exports and store identity remain pending**.

## Constraints already approved

- Primary experience: **Still Pages + Memory Atelier**.
- Dark equivalent: **Midnight Archive**, same content/navigation semantics.
- Journal-first rather than habit/productivity/social branding.
- Calm typography, clear contrast, accessible sizes, original assets.
- The internal working name **Navin Journal** remains unchanged until the final brand is approved.

## Three marks

| Candidate | Files | Intent | Strength | Risk |
|---|---|---|---|---|
| **F1 · Folded Page** | [SVG](../prototype/brand/folded-page.svg) | Two open pages + restrained warm tab | Immediately communicates journaling; scales well at 24–48 px | Open-book marks are a common category; differentiation depends on visual execution |
| **F2 · Quiet Leaf** | [SVG](../prototype/brand/quiet-leaf.svg) | A bookmark-shaped page and calm organic stroke | Gentle, minimal, emotional | Can be mistaken for a reading or sustainability app |
| **F3 · Memory Window** | [SVG](../prototype/brand/memory-window.svg) | Layered pages with a small landscape memory | Communicates photo-led archive experience | Busier at small launcher sizes; more appropriate for Memories than writing-first brand |

**Selected mark direction:** F1 / Folded Page (owner approval on 2026-11-13). It foregrounds writing and uses the clay bookmark as a quiet memory cue. F2 and F3 remain archived exploration alternatives rather than selected product assets.

## Original vector assets

The three SVGs are written directly in the repo, not assembled from third-party logo files. Their visual geometry, colors and descriptions are project-owned source. They contain no external fonts, linked images, scripts, or network dependencies.

## Wordmark

Keep **Navin Journal** as the *internal* wordmark during Stage 3. Do not promote it to the public app name, publish a store listing, or assert that a name/mark is trademark-clear until naming research, availability and owner approval are complete.

Proposed lockup: symbol + an elegant editorial serif title with generous vertical breathing room; system-friendly sans supporting subtitle. No gradients over the writing surface, animated logo loops, glitter effects or layered boxes around headings.

## Color/brand usage

- Light mark container: pine `#475A43`.
- Accent bookmark: clay `#C58B6D` (noncritical detail).
- Page/foreground: warm ivory `#FFFCF7`.
- Dark mode: preserve icon semantics, test contrast at launcher and in-app sizes, don't invert photography.
- Monochrome icon required for status bars and contextual actions in the eventual native implementation; first SVG candidates are **not** signed-off adaptive launcher assets.

## Integrated assets

The selected F1 mark is now present in the Stage 3 Welcome, first-journal setup, desktop sidebar and compact mobile header. Light/dark SVG variations, transparent 108x108 adaptive foreground, full background, monochrome themed layer and staged Android VectorDrawable XML have been created. See [Folded Page asset handoff](BRAND_ASSET_HANDOFF.md). These assets are **not yet compiled into a native app**.

## Review at meaningful sizes

1. Compare on light and dark surface at 24, 48, and 128 CSS px.
2. Render 430 px phone and 1024 px tablet/desktop review screens.
3. Check 200% text scale, dark contrast and icon recognition without reading captions.
4. Ask whether the mark evokes a private journal, distinct from a book reader or photo-storage app.
5. F1 direction has approval and vector/monochrome/adaptive candidate geometry is drafted. Android build compilation, adaptive masking on actual launchers, iOS assets, splash refinement and final wordmark remain pending.

## Source-of-truth and next gate

- [Interactive brand comparison](../prototype/brand-study.html) — a **design-only** page.
- [Design system](DESIGN_SYSTEM_V1.md).
- [Screen specification](SCREEN_SPECIFICATION_V1.md).
- [Roadmap](ROADMAP.md).

The approved F1 visual identity has been added to the main prototype. No production app, actual journal storage or public consumer brand/logo release is implied by these design artifacts.