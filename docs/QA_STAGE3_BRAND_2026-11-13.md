# Navin Journal — Stage 3 identity QA, 13 November 2026

**Status:** Visual identity candidates ready for product-owner review. **No final name or logo has been approved.**

## Source artifacts

- [Brand comparison page](../prototype/brand-study.html) (standalone, interactive, demo-only)
- [Brand direction and decision criteria](BRAND_STUDY.md)
- [Folded Page SVG](../prototype/brand/folded-page.svg)
- [Quiet Leaf SVG](../prototype/brand/quiet-leaf.svg)
- [Memory Window SVG](../prototype/brand/memory-window.svg)

All three marks are original vector source in this repository. The current wordmark, **Navin Journal**, is an internal working name, not a public brand decision.

## Evidence

**Passing CI:** [GitHub Actions run 43393618241](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43393618241)

| Automated suite | Verified result | Coverage |
|---|---:|---|
| Mocked-DOM interactions | 20/20 | Existing navigation behavior |
| Core Chromium | 90/90 | Responsive prototype navigation, writing, reading, themes |
| Extended Chromium | 84/84 | 200% text, Telugu-English/emoji, keyboard-like reduced viewports |
| Keyboard and focus | 33/33 | Skip link, navigation state, dialogs |
| **Brand study Chromium** | **52/52** | Three symbols, selection semantics, light/dark switching, absence of horizontal overflow at 360/430/1024/1280 px, presence of small/large icons |
| Sampled axe-core HTML audit | No serious/critical violations | Previous seven UI screens (does not replace manual QA) |

Screenshot bundle `stage3-ux-screenshots` includes eight new brand review screenshots (phone-small, phone-large, tablet, desktop; each light/dark) as part of the total CI capture, plus the existing core UX capture files. Artifacts on GitHub Actions may expire under retention policy.

## Observations from actual Chromium screenshots

- **Folded Page:** immediate notebook signal, visually confident at header and 28 px contexts, balanced on light/dark. Recommended candidate for discussion, **not approval**.
- **Quiet Leaf:** simple and calm but could be confused for a book reader or nature app. Needs category recognition testing.
- **Memory Window:** fits archive/galleries but has more detail at tiny launcher/icon sizes. Consider as secondary Memories symbol even if not main mark.
- Brand composition uses warm paper, pine, clay and graphite tokens already defined in `DESIGN_SYSTEM_V1.md`.
- The comparison page is a UX artifact; it does not run a journaling database or expose any user data.

## Not yet verified

1. Recognition/blind preference testing with prospective users.
2. Real Android adaptive icon safe-zone masks, monochrome themed icon and iOS launcher asset requirements.
3. Brand name availability/trademark/legal review.
4. Final typography licensing and native platform glyph rendering.
5. Physical-device native visual fidelity and accessibility testing.
6. Product-owner approval of final consumer name, mark, splash screen, and app identity.

## Next gate

Product owner selects a mark direction for refinement (recommended: Folded Page) and confirms the consumer-facing brand strategy. Only then should the chosen identity be applied to the main navigation/editor screen, adaptive launcher assets and welcome experience.

Do not declare Stage 3 complete while real-device and user validation remains open.
