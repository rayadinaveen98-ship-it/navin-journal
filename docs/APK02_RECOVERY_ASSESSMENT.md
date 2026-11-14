# APK 02 — Read-only authenticated recovery assessment

**Status:** encrypted-core assessment verified on Linux (41/41), encrypted background-worker assessment verified (35/35), and read-only review Flutter widget tests passed. **FICTIONAL TEST DATA ONLY.** Native APK 02 compilation is a separate CI gate. Never use the diagnostic APK to store a personal journal.

## Problem and safety boundary

After a crash or forced process termination, a private app directory may contain an abandoned `.navin-journal-restore-*` staging folder. A plausible folder name, an SQLite filename, or a copied `.navin-restore-ready-v1` marker is **not proof of a complete, safe restoration**.

The [existing read-only inventory](../packages/journal_core/lib/restore_staging_inventory.dart) lists candidate folders and symlinks without following links or deleting anything.

The new [RestoreStagingAssessment](../packages/journal_core/lib/restore_staging_assessment.dart) can examine **one explicitly named candidate** under a supplied private directory, only when the caller has **both** the independently authenticated v2 archive/recovery key and the appropriate database encryption key. Its output is a restricted status and nonsecret record counts, not journal titles, text, attachment bytes or decryption keys.

## How it operates

1. Reject unsafe candidate basenames, missing/unsafe directory types, symlinks, unexpected files and oversized input. A strict fixed allowlist permits only the encrypted SQLite database, WAL, SHM and non-secret marker. Stage size is currently capped at **64 MiB** as an engineering constraint, not a production-media limit.
2. Authenticate the independent encrypted archive first. An invalid recovery key or damaged authenticated archive is reported as `untrustedArchive`, without opening a staged database.
3. **Never open SQLite directly in the abandoned folder.** Copy only its encrypted data files into a disposable temporary inspection directory and check original size/timestamps remain stable during copying. SQLite runs against the copy, not the original.
4. Reopen the copied database with the provided database key; perform integrity checking and compare journal, entry, historical revision and attachment records with the separately authenticated archive, ignoring only the generated export timestamp.
5. Report one of `verifiedQuarantined`, `incomplete`, `blocked`, `untrustedArchive`, `notVerified`. A verified match still **does not authorize restore publication**, cleanup, merge, overwrite or resume.

The [PortableRecoveryWorker](../packages/journal_editor/lib/portable_recovery_worker.dart) now exposes a background-isolate adapter for these checks. Raw recovery/database keys are transferred only as isolate data, cleared from owned buffers when the operation completes, and never returned to Flutter presentation.

The [RecoveryAssessmentReview](../preview_app/lib/recovery_assessment_review.dart) is an intentionally informational UI component using the approved Still Pages color system. It displays an unambiguous explanation of the finding with no **Recover**, **Delete**, **Retry**, or other destructive action. Its content is limited to fictional data while the private-beta release gate remains open.

## Evidence

- [Linux encrypted-core run 43564506990](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43564506990): **41/41 tests passed**, strict static analysis clean. The eleven new core test cases validate intact encrypted stages with/without markers, byte-for-byte unchanged original files, wrong recovery/database keys, divergent data, forged markers, corrupt SQLite, untrusted paths/symlinks, missing files and size limits.
- [Encrypted editor/assessment worker run 43564673309](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43564673309): **35/35 tests passed**, strict analysis clean. Three new tests verify authenticated stage assessment over the background isolate, wrong archive-key rejection and refusing traversal names.
- The new Flutter review panel's **five phone/tablet, light/dark and no-destructive-action tests passed** in the [APK02 Library pipeline 43565045914](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43565045914). A passed widget step is not itself a signed or hardware-tested APK.

## Important limitations and next decision

This is an **assessment**, not a safe resumption or reconstruction mechanism. Even a matching staged copy might be concurrently changing, and no filesystem ownership/locking protocol has been certified. Matching content does not independently establish physical durability, device-key safety, or future recoverability. A process killed during assessment may leave an **encrypted** inspection copy in a temporary area; the production cleanup and retention policy still needs design and testing. No private journal text is intentionally written to a plaintext file, but SQLite/Flutter memory and key custody need security review.

Before private-beta release: assess the threat model and original-stage ownership, specify locking/lease and explicit user decision rules, test Android OEM low-storage/reboot/power-loss behavior and large media streaming, and implement a secure human recovery-key workflow.

**Never automatically delete, rename or publish an abandoned stage solely because this assessment reports a match.**
