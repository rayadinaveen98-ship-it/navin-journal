# Full UX screen specification — Stage 3, v1.0

**Approved baseline:** A (Still Pages) + C (Memory Atelier), with B (Midnight Archive) dark theme.  
**Status:** Screen-level behavior specified; production code, final visual screenshots and usability validation remain pending.

## Global shell

- Primary destinations in fixed order: **Today | Journals | Memories | Discover**.
- Persistent Write action: prominent on Today, accessible via app-level action elsewhere. In-editor bottom navigation yields to editing controls and returns after closing editor.
- Contextual overflow includes Settings, Trash and Help; no notification center on the journal home.
- UI is navigable with system back, keyboard back/escape, accessibility actions and app gestures without hidden mandatory swipes.
- Never display a floating action button over text or the keyboard; avoid edge-overlap on small screens.
- Locked vault shows no excerpts, titles, thumbnails, counts or search results unless privacy settings explicitly permit non-sensitive information.

## S01 Welcome

**Goal:** trust and first-write confidence.  
**Layout:** quiet illustrated/header image region optional; minimal brand mark, one-line promise, Create my journal primary CTA, Restore existing journal secondary CTA, Privacy explanation link.  
**Behavior:** account not required; no unnecessary permissions requested on launch; repeat visits bypass welcome after first-time setup.  
**Edge states:** user skips customization; restore unsupported archive; accessibility text expansion.

## S02 First journal setup

**Goal:** create a usable local vault and first journal without friction.  
**Fields:** name (default "My Journal"), optional cover/accent, choose local app lock now or later; explain backups separately.  
**Primary CTA:** Start writing.  
**Behavior:** if vault lock is enabled, recovery guidance must precede commitment; failure to establish encryption prevents misleading success.  
**Edge:** existing vault detection, canceled creation, unavailable secure key store.

## S03 Today

**Goal:** one-tap entry and quick recall.  
**Hierarchy:** date/greeting > primary Write action > existing draft (if any) > recent entries > optional memory throwback.  
**Behavior:** no required mood prompt or dashboard charts; tap entry opens Reader; optional prompt dismissed and preference remembered; Writing CTA must not duplicate a draft unexpectedly.  
**Empty:** "Your journal begins with a single thought."  
**Privacy:** private content hidden on locked device/sensitive previews.

## S04 Writing Studio

**Goal:** frictionless first sentence and long-form composition.  
**Header:** close/back, journal selector, entry date (write timestamp), save status, overflow.  
**Body:** optional title, natural flowing blocks, inline photo/audio, caret-first interaction.  
**Toolbar:** simple add-media, bold/italic/lists/quote when selection/caret requires, attach, optional date/tags/mood through metadata sheet.  
**Behavior:** debounce/cancel saves safely, transactional local commit, local saved/sync distinction, undo/redo, draft recovery, preserve original entry timestamps on edit. No destructive editing based solely on blur.  
**Empty:** no permanent entry if user leaves untouched page.  
**Failure:** show persistent unsaved-change warning and Retry/Copy text; never report Saved before durable commit. Media staging must not corrupt previous content.  
**Tablet:** centered editor column, contextual secondary inspector optional.  
**Keyboard:** toolbar above keyboard without covering text or caret.

## S05 Journal Reader

**Goal:** immersive comfortable rereading.  
**Hierarchy:** content first, title optional, written/event dates both when distinct, journal label, media, optional tags at end, actions Edit/More.  
**Behavior:** Reader preserves original entry; typography and margins user adjustable; next/previous entry navigation scoped to journal or selected filters; avoid accidental edit mode.  
**Media:** fullscreen image viewer with captions and Close; audio playback explicit, never autoplay.  
**Empty/error:** missing attachment shown gracefully with retry information.

## S06 Journals Library

**Goal:** intentionally separate journals.  
**Layout:** ordered personalized covers with count/last changed date; Create journal action.  
**Behavior:** open journal -> list of entries; reorder; favorite; filter; rename, update cover, archive, delete through overflow.  
**Empty:** starter journal or "Create your first journal."  
**Archive vs Delete:** archive removes from active navigation without deleting data; delete moves to recoverable Trash.

## S07 Journal Detail / Settings

**Goal:** configure one journal without changing others.  
**Fields:** name, cover, accent, default status, optional journal-specific lock only after security feasibility validation.  
**Actions:** export this journal, archive, move entries, delete.  
**Behavior:** changes cannot silently move entries to another journal; journal identity stable across renames. Display exact entry count for destructive confirmation.

## S08 Memories / Timeline

**Goal:** browse history in chronological context.  
**Layout:** date range, month/year jump, timeline list with readable thumbnails, optional grouping by year.  
**Behavior:** default to event date only if date semantics are explicit; distinguish a historical event entered today from an entry actually written then.  
**Empty:** invite user to write, or explain filtered period has no entries.

## S09 Memories / Calendar

**Goal:** find entries by day.  
**Layout:** month selector and accessible calendar grid with entry indicators and selectable days.  
**Behavior:** selecting date shows corresponding entries and count; multiple entries displayed independently; timezone and locale rules explicit.  
**Accessibility:** calendar navigates by screen reader and keyboard; not color-only event dots.

## S10 Memories / Gallery

**Goal:** rediscover meaningful photos/media from entries.  
**Layout:** responsive masonry-like or stable grid; captions and entry dates remain accessible, not hidden in photo overlays.  
**Behavior:** select media opens originating entry or viewer; media without an existing entry does not appear by accident.  
**Empty/permission:** "No photographs in your journal yet" and explain that photo-library access is requested only when user adds media.

## S11 Discover / Search

**Goal:** reliable local retrieval.  
**Layout:** persistent query field, clear action, Journal/Date/Tags/Media filter chips, matching entry rows.  
**Behavior:** full text and Telugu-English Unicode input; query highlights without modifying original text; typeahead works in airplane mode; show counts and active filters; saved searches future enhancement.  
**Empty states:** no entries yet vs no matches vs index unavailable vs locked. Index repair must never delete entries.

## S12 Drafts & Revision History

**Goal:** rescue incomplete and previous writing.  
**Layout:** draft list with last edited time and recovery status; version list per entry, read-only diff/preview.  
**Behavior:** restore creates a **new revision** rather than destructively overwriting all history; indicate what changes will occur.  
**Error:** unavailable/corrupt revision must not affect current good revision.

## S13 Archive & Trash

**Goal:** recover intentional and accidental removals.  
**Layout:** tabs or filter for archived journals and trashed items; exact status and deletion dates.  
**Behavior:** restore one or multiple entries where safe; permanent deletion needs clear scope; retention policy disclosed before automatic purging is implemented.  
**Empty:** "Nothing in Trash."  
**Caveat:** local Trash and external backup retention are not identical.

## S14 Privacy & App Lock

**Goal:** make confidentiality understandable.  
**Layout:** local lock settings, device-biometric options if supported, protected previews, key recovery details, export privacy warnings.  
**Behavior:** lock on background/timeout per preference; prevent sensitive content in app switcher and notifications when enabled.  
**Failure:** unlock error provides safe retry/recovery path; no false promise of server-side account recovery of inaccessible encrypted vault.

## S15 Backup / Restore / Import / Export

**Goal:** preserve and migrate complete archives with proof.  
**Layout:** local saved state, last verified backup timestamp, Create encrypted backup, Verify existing archive, Restore, Export readable copies, Import supported formats.  
**Behavior:** validation before replace; preview count and media size, display warnings when key unavailable; restore staging/checks before application; never silently merge or overwrite.  
**States:** creating, verifying, successful and verified, failed (current journal unchanged), canceled, insufficient space, unsupported version.  
**Export:** distinguish editable machine-readable data+media from human-readable PDF.

## S16 General Settings

**Goal:** personalize without feature overload.  
**Groups:** Appearance, Reading & Writing, Accessibility, Language, Privacy & Security, Data & Backups, Reminders (optional), About.  
**Controls:** light/dark/system, preferred text scale/serif, reduced motion, safe image display, notification opt-in.  
**Defaults:** prompt-off, no upload/sync until explicitly chosen, no analytics journal content.

## S17 Optional Sync / Conflicts (future P1)

**Goal:** transparent multi-device state.  
**Layout:** provider/account, last successful sync, current queued changes, recovery key status, error details, sign-out without deleting local vault.  
**Conflict:** show both edited versions, dates and device names when permitted; Keep both / choose version / manually merge; never silent last-write-wins.  
**Failure:** offline doesn't block local writing. No E2EE claim without audited design and implementation.

## S18 Extended memories (future P2)

Life Chapters, Then & Now, Future Letters, Memory Trails and Personal Memory Books may be explored after P0. Their UI must not introduce mandatory prompts or allow generated interpretations to alter original text. Design their content models and opt-in settings before engineering; do not represent conceptual mockups as shipped features.

## Critical common states

Lock, offline, low space, permission denied, invalid archive, media import failure, corrupt thumbnail, changed time zone, missing journal, long entry, very large font scale, airplane mode during sync, action canceled, keyboard open, app returning after force-stop.

Each state needs explicit recovery copy and valid action. No blank spinner, silent overwrite, fake synced label, or dead-end modal.

## Minimum screen review matrix

Phone compact 360dp, phone large 430dp, tablet 768dp portrait, tablet 1024dp landscape, resizable desktop 1280px; light/dark; normal/200% text scale; English/Telugu; with/without image; with keyboard and screen reader. Exact targets may be adjusted based on actual supported devices.
