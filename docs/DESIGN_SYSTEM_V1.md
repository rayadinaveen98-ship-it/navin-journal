# Navin Journal — design system v1.0 (Stage 3)

**Status:** A + C approved as primary experience; B approved as matching dark theme. Component-level visual QA and usability testing remain open. Consumer brand name is not yet approved.  
**Source of truth:** These tokens and rules, not illustrative AI images. Values are initial specifications to validate on actual displays.

## Design intent

**Still Pages:** clear, relaxed, beautifully typeset long-form writing.  
**Memory Atelier:** expressive but disciplined browsing of photographs, dates, and meaningful life collections.  
**Midnight Archive:** low-glare night palette with identical information architecture and no theme-only features.

Never use paper grain behind body text, ornamental elements behind buttons, or high-contrast photographic wallpaper inside the editor. Imagery belongs to covers, memories, and explicit media blocks. Writing always wins.

## Semantic color tokens

| Semantic token | Light | Dark | Use |
|---|---|---|---|
| bg.canvas | #F8F5EE | #15191C | App backdrop |
| bg.paper | #FFFCF7 | #1D2226 | Editor and reader |
| bg.subtle | #EFE8DE | #272D31 | Sidebar, muted surfaces |
| fg.primary | #282923 | #F1EDE4 | Text |
| fg.secondary | #56594F | #B9C0B9 | Supporting labels |
| fg.action | #475A43 | #AEBF9B | Interactive text, links |
| action.fill | #475A43 | #AEBF9B | Main CTA fill |
| action.onFill | #F8F5EE | #15191C | Main CTA text |
| accent.clay | #A45E42 | #D9A289 | Warm accents; not default CTA |
| stroke.default | #DAD6CB | #3B4142 | Dividers / card outlines |
| feedback.error | #A53835 | #FFADA6 | Error messages |
| feedback.success | #3F6848 | #A7D9B0 | Confirmed saved or verified backup |

Initial contrast checks against canvas: light primary 13.47:1, secondary 6.57:1, green action 6.86:1, clay accent 4.53:1; dark primary 15.13:1 and secondary 9.52:1. Component-specific combinations, imagery overlays and disabled states still require automated and human checks.

Do not communicate an operation's status by color alone. Save, sync and verification require readable status words and icons.

## Typography

- Display headings and selected entry titles: **Playfair Display** or an appropriately licensed equivalent; avoid tiny display serif text.
- Reading/editor body: **Source Serif 4**, with system-fallback testing and a script-appropriate Telugu serif.
- UI and controls: **Inter** or system sans; **Noto Sans Telugu** where applicable.
- App title 28–32sp; screen titles 26–30sp; entry title 26–34sp; body 17–19sp with line height 1.55–1.7; UI labels 13–15sp; navigation 11–12sp at default scale, never below supported accessibility settings.
- Long-form line length: 55–72 characters where geometry allows; reading text must not stretch edge-to-edge on tablet.
- Dynamic font scaling must reflow, not clip. Body is not constrained to one fixed pixel size. Text selection, composing Telugu input, and spellcheck must be tested.
- Avoid forced all-caps on sensitive copy; timestamps use locale-aware formatting and explicit time zone context when needed.

## Layout and spacing

4pt base spacing scale: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.  
Mobile content inset: 20–24dp; minimum practical touch target: 48x48dp.  
Writing page max text width: 680–740 logical px.  
Phone compact: width below 600dp, bottom four-destination nav.  
Tablet medium: 600–839dp, navigation rail and single focused content pane.  
Tablet expanded: 840dp and above, rail + optional browse/reader split, writing canvas remains centered.  
Desktop: rail/sidebar, resizable list/detail panes; preserve reading column width.

Breakpoints are initial hypotheses; verify using font scaling, foldables and narrow desktop windows. Respect safe areas, keyboard insets, landscape orientation and system navigation gestures.

## Component inventory

1. **Quiet app bar:** back, journal context, optional tools, overflow. No giant persistent logo in the editor.
2. **Primary Write action:** clear label plus pen icon; visible from Today and reachable in every destination.
3. **Entry card:** date, title or first meaningful line, compact excerpt, optional media thumbnail, journal label; never reveal content before unlocking.
4. **Journal book tile:** customized cover/accent, name, entry count, last-entry date; count only when unlocked.
5. **Paper editor canvas:** focus, caret, natural selection, body blocks; toolbar collapses when not editing rich formatting.
6. **Inline media block:** image caption, accessibility alt description, non-destructive remove, reorder, loading/failure placeholder.
7. **Memory tile:** honest event/write date, media thumb, optional source journal and meaningful one-line excerpt.
8. **Calendar cell:** clear selection, indicators for entries, distinguish day with 1 vs many entries without relying only on colors.
9. **Filter chips:** selection state, removable, keyboard and screen-reader labels; overflow visible.
10. **Search result row:** matching excerpt, date, journal and highlighted query, no plaintext outside locked vault.
11. **Save status:** Saved locally / Syncing / Synced / Needs attention. Not an ambiguous checkmark.
12. **Destructive dialog:** explicit object count, scope, recoverability, and permanent-delete consequences.
13. **Backup status card:** latest verified backup, validation scope, export/restore actions, recovery warning.
14. **Empty and error panels:** useful next action; never blame the user or show invented success.
15. **Bottom nav / rail:** Today, Journals, Memories, Discover. Consistent placement and labels.

Component states: default, hover (pointer), pressed, focused, selected, disabled, busy, offline, empty, failed and accessible high-contrast. Document individual state treatment when components are implemented.

## Motion and interactions

- Navigation: 160–220ms soft fade/slide; never dramatic parallax.
- Button feedback: 80–120ms tactile scale/opacity where supported.
- Page flip animation: **not** default; optional reader transition only if it doesn't delay content.
- Photography: subtle crop/expand with 180–260ms transitions, user controlled; no auto-playing galleries.
- Reduced motion: remove nonessential transforms, use instant/brief opacity changes.
- Haptics: limited to high-value operations where device/platform supports it; optional setting.
- No celebration confetti, streak flames, or ornamental particle systems.

## Iconography and copy

Use a cohesive outlined icon family, optical corrections, 1.8–2px strokes at 24dp, and filled variant only for selected nav state. Core icons: pen, book, calendar, search, back, more, lock, archive, trash, history, cloud, photograph, mic, filter, check. No mixed cartoon/realistic icons.

Copy examples:
- CTA: **Write an entry**
- Editor: **Saved on this device** (only after commit confirmed)
- Sync: **Saved here. Waiting to sync.**
- Restore failure: **This backup could not be verified. Your current journal is unchanged.**
- Lock: **Unlock to view your journal**
- Empty Today: **Your journal begins with a single thought.**

No unsupported promises such as "backed up" merely because a local save succeeded.

## Theme parity QA

Identical navigation order, text styles, active controls, layouts, screen reader labels, and data surfaces in light and dark. Dark doesn't introduce new mechanics. Test OLED dark rendering, disabled buttons, photo caption contrast, keyboard/toolbars and full-screen lock state in both themes.
