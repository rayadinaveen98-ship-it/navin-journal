# Navin Journal — Stage 3 physical-device UX review guide

**Version:** 1.0 · **Date:** 2026-11-13 · **Status:** Pending execution on physical devices  
**Artifact to test:** [Standalone Stage 3 UX preview](../prototype/stage3-ux-preview.html). This is **not an APK**, not a finished journal, and contains fictional demonstration entries.

## Safety and validity first

**Never type a real private diary entry or sensitive personal information into this design preview.** There is no encrypted vault, save functionality, sync, backup or authenticated storage. Text held in memory disappears on reload. Use only the fictional examples below.

The preview is a single HTML file; if your device can open local HTML, download the GitHub file via its **Raw/Download** control and open the local file with your browser. Local HTML opening depends on OS/browser. If the file opens as plain text or the browser blocks `file://`, record the problem; do not assume an APK exists or reconfigure device security to force it to run.

## Target environment

| Device class | Requirement | Actual result |
|---|---|---|
| Android phone | Narrow portrait, system keyboard, touch, landscape rotation | **Pending** |
| Android tablet | Portrait & landscape, optional hardware keyboard | **Pending** |
| iPhone | Safari, native text selection and keyboard | **Pending** |
| Windows desktop | Keyboard, mouse, resize, browser zoom | **Pending** |
| Assistive technologies | TalkBack/VoiceOver/screen reader, font scaling, reduced motion | **Pending** |

This checklist is a qualitative design review, not a production release certification. Note exact device model, OS version, browser version and viewport orientation for each observation.

## Test content (fictional)

**Title:** `నా రోజు — A quiet afternoon`  
**Entry text:** `ఈ రోజు నిశ్శబ్దంగా గడిచింది. I walked outside and wrote down one small thought. 🌿 2026.`  
**Extended writing:** Repeat the sentence 20 times with paragraph breaks, and add a long heading: `నా బాల్యంలోని చాలా అందమైన జ్ఞాపకాల గురించి ఒక చిన్న కథ — a remembered afternoon`.

## Review session (approximately 10–15 minutes if convenient)

| ID | Action | Expected outcome | Result |
|---|---|---|---|
| PD-01 | Open the HTML, tap Begin preview, Continue | Today is visible without a forced account or permissions | Pending |
| PD-02 | Open Writing Studio from Today | Body receives focus; controls and caret stay reachable | Pending |
| PD-03 | Type mixed Telugu+English in title and body | Characters and conjuncts are not lost, substituted or clipped | Pending |
| PD-04 | Place caret mid-paragraph and edit a Telugu word | Selection handles, composing state and text insertion behave naturally | Pending |
| PD-05 | Rotate device while the keyboard is open | Page remains readable and current **temporary demo** text stays intact | Pending |
| PD-06 | Type a long title and 20-paragraph entry | Writing surface expands; toolbar does not cover lower text | Pending |
| PD-07 | Close editor and reopen from same journal | Returns to originating journal; demo text behavior is clearly explained | Pending |
| PD-08 | Navigate to Journal Library, switch journal in Writer | Selected journal is visible and correctly updated in the demo | Pending |
| PD-09 | Explore Memories timeline, gallery and calendar | Items are reachable; readers display legible dates and back navigation | Pending |
| PD-10 | Search for `trip`, clear, enter gibberish | Matching sample entry appears; empty result is understandable | Pending |
| PD-11 | Switch light/dark theme inside Writer | Temporary writing and caret remain; contrast is comfortable | Pending |
| PD-12 | Set type size to 200% in Settings | No horizontal scrolling or clipped essential controls | Pending |
| PD-13 | Open backup preview and simulate failed restoration | Wording makes clear that nothing was actually restored or verified | Pending |
| PD-14 | Use Tab, Shift+Tab, Enter, Escape, Ctrl+K with external keyboard | Focus remains visible; modal cannot be escaped via global shortcut | Pending |
| PD-15 | Enable TalkBack or VoiceOver and navigate all four destinations | Controls have sensible names, order and selected state | Pending |
| PD-16 | Enable reduced motion / system high contrast | No unexpected animation or unreadable text appears | Pending |
| PD-17 | Force reload while demo text is present | Text disappears as documented; **must never be mistaken for a saved real entry** | Pending |

## Severity guide

- **Blocker:** App impossible to navigate, controls inaccessible at supported text scales, false claim that demo writing was saved, sensitive previews exposed while the UI claims to be locked.
- **Major:** Telugu input broken/clipped, keyboard overlaps writing, focus becomes trapped/lost, orientation breaks navigation, actual screenshot significantly differs from approved direction.
- **Minor:** Unbalanced spacing, noncritical typography issue, imagery/copy roughness, subtle animation discrepancy.

Record each problem as `PD-[ID] · device/OS/browser · light/dark · text scale · exact steps · expected · observed · screenshot (if safe) · severity`.

## Accessibility and usability review notes

- **Screen readers:** Navigate with headings, landmarks, buttons, selected navigation item and form labels. Verify the demo preview warning is announced. Verify the restoration-failure dialog captures and returns focus.
- **Keyboard:** Ensure focus indicator is never hidden; repeated Tab cycles should not land on visually hidden navigation, and opening the modal should prevent focus from escaping to the background.
- **Large type:** Check 200% reading and writing on portrait/landscape, including long titles, two-row mobile navigation and journal selectors.
- **Telugu IME:** Test *actual typing and in-progress composition*, not only pasted text. Include Telugu conjuncts, punctuation, emoji and English switching.
- **Privacy:** The demo lock screen is **only a visual simulation**; do not infer device encryption or actual screenshot protection.

## Stage 3 exit criteria (not yet met)

1. Real device observations captured for primary phone and tablet paths.
2. Any blocker/major UX issue fixed, with fresh verified screenshots.
3. Manual accessibility review completed and reviewed; automated axe/Chromium results alone do not count.
4. Consumer-facing brand/logo and final key-screen visual treatment approved.
5. Product owner signs off on the Stage 3 UX handoff before production implementation.

## Latest automated evidence

[Successful GitHub Actions run 43392361821](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43392361821) recorded **20 mocked-DOM**, **90 core Chromium**, **84 extended Chromium** and **33 keyboard/focus** checks passing. Automated HTML axe-core audit found no violations in its seven sampled screens. These tests complement, but do not replace, real-device testing.
