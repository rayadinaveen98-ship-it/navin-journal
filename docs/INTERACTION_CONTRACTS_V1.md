# Interaction contracts — Journeys, states and microcopy

**Purpose:** Make each control's behavior unambiguous before Stage 4.  
**Status:** Design contracts only; not implemented or proven.

## State model

- Vault: Unconfigured -> ReadyLocked / ReadyUnlocked -> Error. Lock hides private content immediately on sensitive transitions.
- Entry: UntouchedCanvas -> LocalDraft -> CommittedEntry -> RevisedEntry -> Trashed -> Restored / PermanentlyDeleted. The original write date never changes when revising unless the user explicitly edits the separate event date.
- Media: Selected -> ImportingToStaging -> Validated -> LinkedToEntry; failure -> DiscardStaged + Error.
- Save: Dirty -> WritingLocal -> SavedLocal (only after durable storage confirmation) -> OptionalSyncPending -> Synced / SyncError.
- Backup: NotCreated -> Preparing -> CreatedUnverified -> Verified / VerificationFailed. 'Created' is not 'Verified'.
- Restore: Chosen -> KeyConfirmed -> Inspected -> Staged -> Validated -> Applied / Rejected. Rejected must leave original vault intact.

## Journey 1 — First five minutes

Entry point: first installation.  
1. Welcome -> Create my journal -> optional name -> Start writing.  
2. Editor automatically receives focus; no forced signup or mood question.  
3. Type a short entry; display 'Saving…', then 'Saved on this device' **only after durable write**.  
4. Close -> Today with saved entry.  
5. Reopen -> exact text.  
**Abort points:** Back before input returns to Today; keyboard dismiss doesn't delete. Re-launch after app kill recovers previous durable content.

## Journey 2 — Quick capture

From any destination, user taps Write. Their default journal and current date are preselected, but editable. Optional photo/audio attachment initiated by explicit intent. A second Write tap while an in-progress draft exists asks to continue that draft or start another (never silently discard or duplicate).

## Journey 3 — Long-form editing

Open entry -> Edit -> caret focus preserving scroll. Format selected range, insert photo between paragraphs, undo/redo, close. Confirm with visual saved state. Formatting may not erase text, reorder blocks or duplicate photo references. On full storage: keep last good revision and offer retry / copy text; don't show Saved.

## Journey 4 — Find a memory

Discover -> search query -> filter -> result -> Reader. Back returns to same query, scroll and filters. Search of journal content is impossible while vault is locked; if unlock succeeds, return to pending search only if secure.

## Journey 5 — Calendar to entry

Memories -> Calendar -> choose month -> day -> entry list -> Reader. Show event and written dates accurately. Multiple entries on a day are individually reachable. A blank date says there is no entry on that date, not 'missing data'.

## Journey 6 — Journal management

Journals -> Create/Rename/Cover/Archive. For Delete, present exact number of affected entries and destinations (Trash), plus Undo where available. Journal rename does not change entry IDs. Restore allows selecting a new journal if original was permanently removed.

## Journey 7 — Accident recovery

Trash -> select item -> Restore -> confirmation. Restored content, attached media and metadata must match last recoverable snapshot. No destructive replacement of current entries without explicit merge resolution. Empty Trash includes a route back.

## Journey 8 — Backup and migrate

Settings -> Data & Backups -> Create encrypted backup -> Verify -> share/store file intentionally. New device -> Restore -> choose file -> authenticate/decrypt -> inspect counts -> validate -> apply -> re-open random sample and attachment summary. Current data unchanged on tampered or interrupted archive.

## Journey 9 — Dark/light mode

Settings -> Appearance -> System / Light / Dark. Switching preserves current editor scroll, text selection if supported, content, focus and pending save state. Entire UI color tokens switch; no hard-coded white cards left over.

## Journey 10 — Offline and optional sync

Unplug network. All local entry and search operations continue. Show 'Saved on this device' plus 'Waiting to sync' rather than cloud success. On re-connect, queue safely; if conflict, user sees both versions and can keep both. No automatic permanent delete.

## Dialog and confirmation language

- Delete entry: "Move this entry to Trash? You can restore it until it is permanently deleted."
- Delete journal: "Move [journal] and its [n] entries to Trash?" Expose exact scope, not an ambiguous yes/no.
- Permanent delete: "Permanently delete [n] selected entries? They cannot be recovered from this device's Trash. Existing backups may still contain copies."
- Save problem: "Changes could not be saved. Your last saved version is safe. Try again or copy this text."
- Backup verification failed: "This backup could not be verified. Your current journal is unchanged."
- No network: "Offline. You can keep writing; syncing will resume later if enabled."
- Key loss: "Without the recovery key or a valid decrypted backup, protected data may not be recoverable."

## Failure policy

No action may falsely report success. Use inline, non-modal status for routine operations; dialogs for irreversible choices, key-loss risks and overwrite questions. Error states must preserve content and propose a safe path. Screen-reader announcements should report true save/error states without reading private journal text aloud by default.

## Design-to-engineering handoff requirements

For each flow, engineering records its durable-storage event, recovery action, analytics prohibition, relevant security threat and automated test ID. Never assume a mock screen is proof of encryption, autosave, or backup functionality.
