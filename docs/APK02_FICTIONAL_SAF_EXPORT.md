# APK 02 — User-selected fictional encrypted archive export (Android SAF)

**Stage 5 checkpoint:** 14 November 2026  
**Status:** implementation merged, strict tests and Android debug APK compiled; **physical Storage Access Framework picker interaction and real independent-device restore remain untested.** Do not enter private diary data.

## The actual new flow

The **fictional encrypted Library → Review restore safety** screen now includes **Export fictional encrypted file**. This does not perform a restore or overwrite the current journal.

1. Only after an explicit tap, the existing `JournalEditorWorker` exports a consistent full-schema v2 **AES-256-GCM** archive containing the *scripted fictional* journal and its metadata/history/media. It generates a fresh, independent random 256-bit recovery key unrelated to the device-bound Android Keystore database key. The archive is internally authenticated/validated before the Android picker is invoked.
2. The native test bridge opens Android **Storage Access Framework `ACTION_CREATE_DOCUMENT`**, allowing the user to select a document provider. The only payload sent to the native bridge is already-encrypted ciphertext, never journal plaintext or the recovery key. The file name defaults to `navin-journal-FICTIONAL-only.njr`.
3. A successful document provider write is **not enough**. Kotlin closes the output stream, opens the selected document for reading, and checks exact byte count and SHA-256 digest. On cancellation no key is shown. On provider failure the UI does **not** claim the document is valid; a partial/unusable ciphertext file may remain and is never automatically deleted.
4. Only after successful readback does Android enable the secure-window flag **`FLAG_SECURE`** and acknowledge the operation. Then Flutter displays the 43-character recovery key in a **one-time, non-selectable text view**. The user must write it down separately **OFF the device**, not next to the archive. The app offers no Copy, Share, SMS, email or persistent key-storage option.
5. When the user hides the key, backgrounds the Activity, leaves the screen or the widget is disposed, the displayed key is removed and the native secure-window flag is cleared. An immutable Dart/JVM string cannot be guaranteed byte-zeroized; no production assurance is claimed. The key is not written to journal metadata, local preferences, logs, clipboard or a cloud account by the app.

This is a **debug-only**, fictional-data-only feature. Native code requires a debuggable Android application and the Dart service rejects product/release mode. The existing encrypted Library and recovery assessment display still lack production input, automatic restore, permanent delete and archive-import controls.

## Verification evidence

[Successful Library & APK workflow 43581837392](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43581837392):

- Strict Flutter analysis — **PASS**
- Autosave & unfinished IME controller — **46/46 PASS**
- Encrypted editor + portable export/recovery worker — **41/41 PASS**. New tests cover: copying encrypted output and separately retaining a recovery key; **deleting the original database**, then restoring from only that archive + key to a *new* vault with a *new* database key; encrypted integrity, old entry ID and revision history; cancellation with zeroed ciphertext/no key; provider failure without key; and refusing an unavailable source.
- Visual/editor widget tests — **16/16 PASS**
- Library/index/widget integration — **29/29 PASS**. Includes opt-in Library → Restore Safety → Export presentation and verification that the active encrypted journal is unchanged.
- Recovery safety review — **5/5 PASS**
- Native Kotlin bridge + Flutter Android debug APK — **compiled and uploaded PASS**.
- GitHub artifact ID **14108876924**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

[Successful API-34 Android regression 43581837391](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43581837391): existing Android Keystore, synthetic Telugu composition, real Android HOME, force-stop, encrypted reopen and revision checks **PASS**. The new Kotlin file-picker bridge was included in the compiled Android app, but this test **did not automate tapping the actual system picker**.

Code merged via [PR #8](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/8), squash commit `14f459680c352456268095799192472549687139`.

## Strict claim boundaries

- **Not a verified backup on another device:** provider readback is not independent device access, retention, sync, or successful restore. The clean-vault restore contract is proven in a Linux isolated worker test, **not** by a person importing a chosen SAF document on a new handset.
- **Not verified recovery-key custody:** the app *displays* a key; it has no way to prove someone copied it off-device correctly or stored it securely.
- **No external archive import yet:** future Android `ACTION_OPEN_DOCUMENT` selection, bounded authentication, key re-entry and fail-closed restore into an absent directory need implementation and physical Android verification.
- **No protection guarantee from FLAG_SECURE:** it requests Android screen-capture and non-secure-display prevention, but hardware/OEM/overlay attacks and memory zeroization are not solved by that flag.
- **Possible partial file:** a provider may create a document then fail write/readback. The app refuses success and deliberately does not delete or overwrite untrusted provider documents.
- **No real diary input:** all APK02 data must be scripted fictional fixtures; do not use this diagnostic for personal writing or call it a private-data beta.

## Required on-device QA (PENDING)

1. Install the debug-only fictional Library APK from the successful Actions artifact on an Android test phone. Open **Review restore safety → Export fictional encrypted file**, choose a storage provider you control and verify the file is created. Do not enter real private content.
2. After readback, verify that only the key screen is protected against normal screenshots and that it disappears when leaving/backgrounding; do not capture, send or paste the key in ChatGPT. If the picker is cancelled, no key should appear.
3. Verify the resulting ciphertext file separately from the source APK, test provider error/cancellation behavior, and repeat on a tablet with a different document provider.
4. Then build and test the **new-device import + non-destructive restore** flow using an independently retained file and manually re-entered key, including invalid key/tampering/full disk scenarios. Never overwrite an occupied vault.

**Next roadmap gate:** `ACTION_OPEN_DOCUMENT` archive import, external recovery-key re-entry, bounded authentication and safe new-vault Android handoff; verify this on actual physical devices before any private-data beta.
