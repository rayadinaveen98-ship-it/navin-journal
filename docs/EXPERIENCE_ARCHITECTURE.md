# Experience architecture — v0.1

## Navigation

Four persistent destinations: **Today**, **Journals**, **Memories**, **Discover**. A consistent **Write** action is available from any destination. Settings, privacy, import and backup live under a secondary menu. Navigation adapts to tablet/desktop side rail.

### Today

A calm reading/writing entry point: one prominent Write action, current draft (if any), and a restrained set of recent entries. No engagement streak pressure, large inspirational feed, notification center, or gamified productivity dashboard.

### Journals

Actual **separate journal records**, not a single diary with filters only. Create/rename/reorder/change cover/archive/delete journals; each can have entries, themes, optional privacy rules, and an optional default. Confirmation and Trash for destructive actions.

### Memories

Calendar / timeline / gallery views over the same archive, not copies of entries. Preserve *event date* separately from *written date*. Date browsing must handle time-zone changes and historical edits honestly.

### Discover

Full-text search of text content with filters for journal, entry/event date, tags, attachments and favorites. Search must be local on private offline mode. Search index is security-sensitive.

## Essential flows

### 1. First write

1. App opens to onboarding or Today (no forced account).
2. Choose "Create journal" or accept a private starter journal.
3. Tap Write; focus immediately enters editor.
4. Write plain text; formatting tools are concealed until needed.
5. Periodically commit meaningful text to local durable storage and show an understated saved indicator.
6. Closing returns to Today; populated entry appears in the correct journal. An untouched empty page creates no clutter.
7. After abnormal termination, recover last committed revision and pending draft state.

### 2. Long-form entry

Title optional. Body supports structured paragraphs, quotes, headings, lists, emphasis and links. Inline media blocks where appropriate. Full-screen focus, font size, dynamic type, keyboard shortcuts, accessible toolbar, undo/redo and version history. No template or mood requirement.

### 3. Capture via media

Start with a photo, audio or another supported shared item. Entry owns references to media; asset import is transactional and verifiable. Failed or canceled imports must leave the existing journal readable and not create misleading broken references.

### 4. Find and revisit

From Memories, filter year/month/day, find entry, open readable page, navigate neighboring entries, choose Edit. If entry was written later about an earlier event, show both dates clearly rather than implying the entry existed in the earlier year.

### 5. Recover deleted entry

Move to Trash with expiration policy explained. Restore to original journal when it exists, otherwise choose another. Permanent deletion requires explicit user action; behavior of replicated/backup copies is explained.

### 6. Device migration

Choose restored archive or connected encrypted synchronization; verify key availability; display contents summary; restore to a temporary staging store, validate metadata and media hashes, and commit atomically when possible. Show final verification. Never overwrite an existing local vault silently.

### 7. Two-device editing (when sync ships)

Each device edits its local copy. Sync identifies concurrent revisions using stable IDs/version metadata and preserves both conflict branches until resolved; never silent last-write-wins for entry content.

## Screen inventory

1. Welcome / permissions explanation (no forced sign-in)
2. First journal setup
3. Today
4. Writing studio
5. Reader
6. Journals library
7. Journal settings
8. Memories: timeline, calendar, gallery
9. Discover: query and filters
10. Drafts / revision history
11. Archive / Trash
12. Privacy / lock
13. Backup / import / export / restore
14. General accessibility, typography, and notification settings
15. Optional sync setup/status (not P0 if not feasible)

## Empty, loading and failure states

Design every relevant state: no journals, no entries, first image attachment, encrypted vault locked, insufficient storage, denied photo permission, failed sync, backup mismatch, unsupported import, deleted journal restore, airplane mode, large archive load. No full-screen splash/loading mask that blocks existing local writing for a network operation.

## Phone & tablet

- Phone: single-column editor, restrained bottom navigation, persistent focus.
- Tablet: responsive rail, optional library/reader split view, page max-width and margins for comfortable long-form reading.
- Desktop later: proper keyboard navigation, resizing and shortcuts, and the same save semantics.
- All: screen reader labels, dynamic text, reduced-motion mode, touch target accessibility, contrast and RTL considerations if expanded internationally.

## Editorial behavior

Prompts must be dismissible and optional. The default editor starts blank. Emotions, tags and location are opt-in metadata. Contextual memory suggestions need explicit permissions and should not surprise users with private data.
