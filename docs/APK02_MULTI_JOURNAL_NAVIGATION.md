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
- PR branch Android workflow: `.github/workflows/apk02-library-debug.yml`; it must pass analysis, worker/widget/real encrypted navigation/recovery tests and compile the Android debug APK.
- Until there is a passing run, this is implemented but **NOT verified**. Even after a passing run, physical phone/tablet UX, power-loss, key custody and independent security assessment remain open.

## Release gate

Do not merge private-data readiness into these results. Product launch still requires user-driven physical device acceptance, real input method/accessibility, durable independent recovery and security audit.