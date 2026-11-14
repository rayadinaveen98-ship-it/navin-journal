# APK 02 — encrypted multi-journal navigation (fictional diagnostic)

**Scope:** Stage 5, independent fictional notebook navigation in the Library/Reader/Writer diagnostic. **Do not enter real diary data.** This is not a private-data beta.

## Implemented

- The Library reads a journal catalog from `JournalEditorWorker.listJournals()`. Journal names are decrypted by the single background isolate and held only in transient widget memory. No SharedPreferences/cloud/plaintext selection cache.
- A journal selector is visible inside the Library only. Switching is disabled while opening a reader, editing, or reviewing interrupted restore. Each selection reloads just the selected journal's `listEntries(journalId: ...)` and clears the old list/filter/sort first.
- Reader and prior-version history verify the entry/revision's journal ID. Writing Studio sessions are opened with the selected journal ID, while the existing core checks that previously saved entry IDs belong to that journal. Archived journals are shown as read-only.
- A QA-only add button creates a predefined imaginary notebook; no user input, import, or personal data is permitted.
- Android diagnostic startup reopens an existing encrypted vault with one or more journals, choosing the newest writable journal (otherwise an archived journal for read-only inspection). It does not auto-recreate missing/trashed journals. Existing data or keys are never silently reset.

## Scripted regression tests

The new Flutter real-worker integration tests include:
1. Two encrypted notebooks, switching, cross-journal page isolation, read-only Reader, scripted save to the selected journal and a safe switch back.
2. Scripted notebook creation, isolated entry storage and in-memory-only selection reset after widget recreation.
3. Pre-archived encrypted journal loaded by worker, Reader available, create/edit buttons disabled, and original encrypted entry ownership unchanged.

Existing Library/Reader/Writer navigation, bilingual preset search, earlier-version history, read-only recovery assessment and visual widget tests remain in the full CI gate. This stage does not implement user-created journal names, archived journal management UI, production custom search, genuine text input, large data performance or cross-platform backup.

## Validation

- Source pull request: https://github.com/rayadinaveen98-ship-it/navin-journal/pull/1
- **Verified passing CI:** [APK 02 multi-journal debug run 43568957683](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43568957683) on 14 November 2026. Strict Flutter analysis passed; **35/35** encrypted editor/recovery worker tests, **13/13** stable visual/editor widget checks, **19/19** encrypted Library navigation and pure index checks, **5/5** recovery safety verdict tests passed; Android debug APK compiled and uploaded.
- **Artifact:** `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`, GitHub artifact ID `14103815467`. This is a **fictional-only test APK**, not a secure private diary. Installation on physical phone/tablet still needs user confirmation.
- **Merged:** [PR #1](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/1) via squash commit `49730b91d1c329c78bbb4abc951a837e81730104`.
- **Still open:** physical phone/tablet UX, power-loss, recovery-key custody, large data and independent security assessment.

## Release gate

Do not merge private-data readiness into these results. Product launch still requires user-driven physical device acceptance, real input method/accessibility, durable independent recovery and security audit.