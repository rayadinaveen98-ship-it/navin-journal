# APK 02 — Fictional Android encrypted archive import and manual-key recovery verification

**Checkpoint:** 14 November 2026 · Stage 5 functional engineering slice. **PR #9 merged.**
**Release boundary:** FICTIONAL DATA ONLY. Android debug APK; NOT a production backup/restore, private diary beta or physical clean-device certification.

## What a user can now do

In the fictional encrypted Library open **Review restore safety → Fictional encrypted archive import → Choose fictional encrypted file**:

1. Android `ACTION_OPEN_DOCUMENT` displays the system picker. The user selects an existing encrypted `.njr` archive. The Android bridge accepts at most **32 MiB** of ciphertext and refuses concurrent import/export picker operations. It enables the `FLAG_SECURE` window flag **before launching the picker** to protect subsequent key-entry UI. The native bridge never accepts or stores the manual recovery key.
2. The app displays a masked **Manually re-enter 43-character recovery key** field. Suggestions/autocorrect/interactive selection are disabled. The key is not logged, persisted, copied or sent to Android native code; it is passed only to the Dart authentication/restoration worker and cleared from the TextEditingController after submission. Dart String/Flutter codec memory cannot be guaranteed zeroized.
3. **Verify in separate encrypted vault** authenticates the full AES-256-GCM v2 archive with the re-entered independent key. Wrong, malformed or tampered input fails with a generic error. No user data appears in the result UI.
4. With a new random database key, `PortableRecoveryWorker.restoreToNewVault` restores inside a **uniquely created disposable directory** under the trusted app-private root. The existing restorer validates the entire schema before staging; its Linux/Android native publication uses no-replace semantics and file/directory synchronization. The app then independently reopens the new encrypted SQLite vault using a separate worker, checks database integrity, notebook/page ownership and history counts.
5. On success, UI shows **only aggregate journal, page, revision and attachment counts**, together with **TEMPORARY REVIEW ONLY**. It explicitly confirms that the restored test vault was removed, no active journal was overwritten and no usable new journal was installed. Both success and failure destroy ephemeral keys and delete only the unique disposable inspection directory; no unknown staging folders are auto-deleted.
6. Cancel, background or leaving before submission clears the selected in-memory ciphertext, removes the key field and releases the import-specific `FLAG_SECURE` state. The existing export-specific secure window state remains separate.

This **verifies an imported encrypted file and manually re-entered recovery key**, but does not import the recovered pages into the current diary. It does **not** create a durable restored vault or persist a new Keystore key envelope. Device loss/clean-device recovery signoff is still open.

## Evidence

**Passing Android Library pipeline:** [GitHub Actions run 43583688287](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43583688287).

- Strict Flutter/Dart analysis: **PASS**.
- Autosave and IME: **46/46 PASS**.
- Encrypted editor / archive export-import recovery worker: **45/45 PASS**, including separate encrypted vault creation and independent reopen, wrong key, ciphertext tampering, invalid key, missing private root, untouched original journal, unknown staging candidate preservation, and sensitive input buffer clearing.
- Stable Flutter visual/editor: **16/16 PASS**.
- Real-worker Library/index/widget integration: **30/30 PASS**, including the new opt-in imported-archive flow and unchanged active encrypted entry.
- Read-only recovery verdicts: **5/5 PASS**.
- Android Kotlin + Flutter **debug APK compiled and uploaded**: **PASS**. Artifact ID **14109587802**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY` (ZIP contains `app-debug.apk`).

**Android native regression:** [Run 43583688293](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43583688293) — **PASS**: real Android API-34 HOME, Keystore, synthetic Telugu composition, app force-stop and encrypted reopen tests. Kotlin bridge was compiled. **This run did not drive the Android file picker or enter the recovery key by hand.**

**Merged PR:** [#9](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/9), squash commit `1b6cb35c1c42bfa64805dd4825118c1f45f0f9c6`.

## Mandatory real phone/tablet QA — NOT YET VERIFIED

1. On Android test hardware, use the fictional APK **Export fictional encrypted file** action to save a `.njr` archive in a document provider. Write the separate key **on paper**. Do not send or photograph it.
2. Open **Fictional encrypted archive import**, pick the exact exported file and manually re-enter its 43-character key. Confirm that the test reports aggregate counts and says **TEMPORARY REVIEW ONLY**, with the existing fictional notebook still intact.
3. Try cancellation, wrong key, tampered copy, an empty file, a provider with read errors, a different file provider and a second phone/tablet. Observe the Android secure-screen flag and verify that app backgrounding clears unsubmitted input.
4. Repeat using a **fresh debug-app install on a different Android device** with separately retained ciphertext/key. Because this implementation discards the recovered vault and has no durable new-device Keystore envelope, count only *import verification*, not a usable restored diary.
5. Never put the recovery key, sensitive screenshots or real journal writing into this diagnostic or send the key into the chat.

## Next hard release gate

Implement and validate **durable new-device key custody + non-destructive activation** for a user-approved newly restored journal, with collision-safe crash recovery, interrupted stage inspection, low-storage/power-loss and different-OEM tests. Then physical Telugu keyboard, accessibility and independent security/privacy audit. No personal diary beta until those gates pass.
