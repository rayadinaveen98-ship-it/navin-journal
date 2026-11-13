# Stage 3 extended accessibility, typography and bilingual UX QA

**Date:** 2026-11-13  
**Repository:** `rayadinaveen98-ship-it/navin-journal`, `main`  
**Status:** Automated HTML prototype validation passed; Stage 3 real-device and user validation is still open.  
**Evidence:** [Passing GitHub Actions run 43391287664](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43391287664).

## Passing automated tests

| Suite | Result | Scope |
|---|---|---|
| Mocked-DOM navigation | **20/20** | State transitions and expected copy in sample prototype |
| Core Chromium | **90/90** | Responsive phone/tablet navigation, writer, reader, search, dark mode, simulated backup/lock |
| Extended Chromium | **84/84** | Telugu–English/emoji input, 200% type scaling, journal selection, Back navigation, focus and simulated keyboard-height viewport |
| Axe-core WCAG 2.0/2.1 A/AA | No automated violations in **seven sampled HTML screens** | Welcome, setup, Today, Writer, Reader, Memories Gallery, dark Discover |

Four viewport profiles: **360×800**, **430×932**, **768×1024**, and **1024×768**. Screenshot output includes 40 rendered PNGs plus `accessibility-audit.json` in the GitHub Actions artifact `stage3-ux-screenshots`.

Important: These are browser and mock checks. The test that reduces viewport height to 500 pixels is only a keyboard-occlusion approximation and **does not validate Android/iOS IME behavior**. The bilingual text test uses browser text filling rather than real Telugu keyboard composition.

## UX issues addressed in this pass

1. **Editor origin:** Closing an entry now returns to the source destination (Today, a specific journal, or Reader) instead of always returning to Today.
2. **Journal picker:** The writing screen allows switching the preview draft between named journals.
3. **Text resizing:** Appearance/settings offers reversible 100%, 125%, 150% and 200% type-size previews. The layout reflows without horizontal page overflow in the four tested viewports.
4. **Long titles:** Entry title changed from a one-line input to an auto-expanding textarea, so large-type titles wrap instead of disappearing to the side.
5. **Telugu/English:** Mixed text and emoji are preserved exactly through the preview's edit and theme re-render paths.
6. **Page focus:** Switching themes preserves the current temporary draft and refocuses the writing control; dialog focus moves into the modal and returns to its invoking action when the modal is closed.
7. **Reduced-height viewport:** No page-level horizontal overflow during the simulated compact keyboard viewport.
8. **Visual polish:** Condensed and un-stuck the prominent demonstration banner and removed a redundant second Close action in the editor.

The preview does not persist data; therefore these passing tests **must not** be interpreted as evidence of autosave, database correctness, encryption, cloud sync, backup integrity, or recovery.

## Screenshot observations

- **360px phone, default text:** Calm writing hierarchy and clear four-destination navigation.
- **360px phone, 200% text:** Titles wrap, body text is readable, and the page has no horizontal overflow; increased vertical length is expected at accessibility sizes.
- **1024px landscape tablet:** List/detail Reader and centered writing column are present.
- **Both themes:** Core controls remain discoverable and retain content in the in-memory sample.

Illustrations are CSS-drawn placeholders; final brand artwork, entry media treatment and actual product visual assets remain to be designed.

## Stage 3 exit gate — remaining

- Product owner approves screen-level aesthetics and final consumer brand/logo.
- Physical Android phone/tablet testing for keyboard insets, IME composition, scroll and focus; iOS/Windows parity still unverified.
- Human TalkBack/VoiceOver and 200% native text-scaling review, including manual focus order and contrast validation.
- Representative user trials for first journal, entry recall, deleted-item recovery understanding, and backup comprehension.
- Stage 4 security/architecture proof of concept with explicit local vault and backup/restore evidence.

No APK, native journal app, encrypted storage, backup engine or sync functionality has been produced in Stage 3.

## Reproduction

Run in `prototype`:

```bash
npm install
npx playwright install chromium
npm run check:smoke
npm run check:browser
npm run check:extended
npm run check:a11y
```

The [workflow](../.github/workflows/stage3-ux.yml) runs the same suites on GitHub Actions and uploads screenshots/audit output for review.
