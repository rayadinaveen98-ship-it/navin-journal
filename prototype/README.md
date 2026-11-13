# Stage 3 UX review prototype

Open **stage3-ux-preview.html** in a desktop or mobile browser after downloading the HTML file from GitHub (use the file's Raw/Download action). No server, login, build tools, external assets or network are required.

## What you can review

- Welcome -> first-journal setup (simulation) -> Today -> one-tap writing concept.
- Journals library -> journal detail -> journal-aware Writer; sample Reader with tablet list/detail layout.
- Memories -> timeline/calendar/gallery -> sample entry.
- Discover -> sample full-text search and reader navigation.
- Settings -> light/dark theme parity, navigable simulated lock/backup states (including restore rejection), and Trash.
- Responsive phone/tablet/desktop adaptation; basic keyboard shortcut Ctrl/Cmd+K for Discover.

## Important limitations

**This is a product-design prototype, not Navin Journal production code.**
- Editor input is held only in volatile browser memory for the current preview session and is lost on reload. It does not create saved journal entries.
- All journal entries and counts are fictional sample content.
- All images are CSS illustrations; they are not user photos.
- Encryption, local storage, account management, synchronization, backup, restore, media import, journal creation and deletion are **not implemented**.
- Some buttons intentionally open explanatory concept dialogs rather than perform real actions.
- There has not yet been browser/device/screen-reader testing. Do not infer reliability or accessible operation from the presence of markup alone.
- The HTML is a UX artifact; the real application technical stack remains to be validated.

## Review checklist

1. Try the four navigation tabs and the Writing Studio on a small phone viewport.
2. Open Reader from Today, Journal Library, Memories and Discover; verify Back semantics.
3. Switch between light/dark and inspect readability.
4. Test keyboard opening, scrolling and long text; report clipping or awkward spacing.
5. Review backup and privacy concept dialogs; verify they clearly distinguish intent from functionality.
6. List anything that feels too busy, visually weak, or inconsistent with the A + C hybrid.

Keep all feedback scoped to UX/design during Stage 3. Engineering begins after the design and data-integrity gates are approved.

## Real Chromium QA

Run `cd prototype && npm install && npx playwright install chromium && npm run check:browser` or use the GitHub Actions `Stage 3 UX Chromium review` workflow. It captures 24 viewport screenshots and runs a set of real Chromium navigation/layout checks. Latest verified result: 90/90 browser checks on 13 November 2026; see `../docs/QA_STAGE3_2026-11-13.md`. These checks do not verify actual journaling storage, native device behavior, or accessibility end-to-end.

## JavaScript smoke checks

Run `node prototype/tests/smoke.mjs` from the repository root (requires Node.js). The 20 checks simulate navigation and read the rendered HTML strings with a mocked DOM. They do **not** verify actual browser rendering, keyboard input, screen reader operation, saving, security, accessibility, or network behavior.

**Finding (2026-11-13):** a JavaScript syntax error in the original Discover placeholder prevented the prototype script from parsing. Fixed; a syntax assertion and interaction smoke checks were then performed before later refinements.

## Accessibility smoke audit

Use `npm run check:a11y` after installing dependencies. This injects axe-core into seven simulated screens and saves `artifacts/accessibility-audit.json`. Automated checks found no violations in the sampled states on 2026-11-13. This is **not** a native accessibility certification; human screen-reader and enlarged-text reviews remain necessary.

## 200% typography and bilingual preview

Use `npm run check:extended` to run the Chromium checks for the text-size selector (100/125/150/200%), journal-aware editing, Telugu–English/emoji content, large-title wrapping, simulated reduced-height keyboard viewport and modal focus restoration. Latest passing run: [43391287664](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43391287664). This **does not** validate native Telugu IME or persistent data.
