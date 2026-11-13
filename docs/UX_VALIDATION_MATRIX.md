# Stage 3 UX validation matrix

**Status:** Planned tests, not executed.

## Participants and tasks

Recruit 8–12 prospective journal users representing first-time, long-form, memory-heavy, privacy-sensitive and multi-device behaviors, including at least two people who write bilingual or Telugu content. This is an initial qualitative validation sample, not a statistical benchmark.

Ask participants to:
1. Start a journal and write their first entry without help.
2. Close/reopen a partially written entry and identify saved state.
3. Attach a photo mid-paragraph, add a short caption.
4. Create a second journal and move an entry intentionally.
5. Find an entry from an old date; distinguish written date from event date.
6. Discover a memory by phrase, journal, and date filter.
7. Locate Trash and restore a removed entry.
8. Explain the difference between saved locally, backed up, and synced.
9. Inspect a backup/restore failure screen and predict whether existing content is safe.
10. Change theme, enlarge text, and continue writing without losing focus.
11. Browse journal on tablet split view and return to the editor.
12. Attempt these tasks on mixed Telugu/English input where applicable.

## Design quality dimensions

Score each 1–5 after observation; collect verbatim comments:
- First-write confidence; perceived calmness; clarity of controls; long-form readability;
- Findability of old entries; sense of data ownership; trust in save status;
- Discernibility of errors; color/contrast; tap targets; tablet adaptability;
- Perceived identity and distinctiveness vs familiar journals.

## Heuristic checks

**Navigation:** exactly four destinations with predictable state restoration, write always reachable, no dead ends.  
**Typography:** large text reflows, body measure is comfortable, Telugu characters not clipped, caret/cursor visible.  
**Media:** captions, loading states, non-destructive removal and graceful failure.  
**Privacy:** locked state never leaks titles, previews or thumbnails.  
**Backup:** users understand whether an archive was created *and verified*.  
**Error UX:** full-storage and invalid backup errors never imply silent data loss.  
**Accessibility:** screen readers, keyboard, high contrast, reduced motion, system font scaling, input methods.  
**Responsive:** 360/430dp phones, 768dp tablet portrait, 1024dp tablet landscape, 1280px desktop target.  
**Theme parity:** core actions and hierarchy consistent in light/dark.

## Stage 3 design deliverables and gates

| Deliverable | State |
|---|---|
| A + C primary with B dark visual direction | Approved |
| Semantic tokens and typography specification | Drafted; physical-device review pending |
| 18-screen full UX specification | Drafted; stakeholder and user review pending |
| Journey contracts and failure states | Drafted; engineering feasibility pending |
| Connected screen mockup study | Concept generated; not pixel-verified |
| Interactive flow prototype | HTML review prototype committed; functionality not browser-tested |
| Actual user validation | Not started |
| Brand/consumer name and logo approval | Not started |
| Engineering spike for text editor and encryption | Not started (Stage 4) |

## Exit criteria for Stage 3

1. Approved final brand/visual system and detailed key-screen mockups in phone + tablet.
2. Prototype review of first-write, editor, reader, journal library, memories, search, Trash and backup.
3. Core edge states designed; full text-scale and accessible contrast checks performed.
4. UX usability observations logged and P0 blocking issues resolved.
5. Decision register updated with actual approvals and any technical risks.

No Stage 3 completion claim without the checks above.
