# APK 02 — Synthetic Telugu IME and background autosave safety

**Checkpoint:** 14 November 2026. Stage 5 engineering slice, fictional fixtures only.
**Status:** Verified Flutter/Dart tests and Android **debug APK build**; **NOT a private journaling beta**.

## Why this slice exists

A composing keyboard (including Telugu IMEs) can hold an unfinished preedit. Treating a lifecycle-flushed partial preedit as permission to dismiss the writer could silently lose the user's intended completed word. Android may also send multiple inactive/hidden/paused events per backgrounding transition; they must not be interpreted as multiple successful saves.

## Implemented

- `DraftAutosaveController.closeSafely()` refuses to close while `isComposing` is true, both before and after the forced-flush attempt. Background/lifecycle `flush()` is still permitted to preserve a best-effort preedit snapshot but cannot authorize editor dismissal.
- `ConnectedWritingStudio` coalesces a group of inactive/hidden/paused lifecycle callbacks into one in-flight background request. It awaits that request internally and consumes asynchronous errors; no success badge is shown without the existing save state machine's durable commit acknowledgement.
- On attempted dismissal during active composition, the existing safe-exit dialog explains that keyboard composition must finish before leaving. No new appearance system, menu, production free-text input, or plaintext cache was introduced.
- All diagnostic UI text fields remain read-only for users. Flutter tests inject **fixed fictional** Telugu/emoji `TextEditingValue` instances directly into controllers. This is **not** a test of a real physical Android keyboard.
- Added encrypted-worker synthetic preedit scenario: a partial fictional Telugu draft can be force-flushed to an encrypted journal, editor close is refused, finalized text is persisted with a later revision, and both states survive a clean worker close/reopen. This is **not** an OS kill.

## Verified CI

**Passing [GitHub Actions run 43571626717](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43571626717)** after [PR #3](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/3), merged at `b9880f6edb2570979d1df9449db8819236ed3f54`:

- Strict Flutter/Dart analysis — **PASS**.
- Autosave controller regression tests — **46/46 PASS**.
- Encrypted journal editor/recovery worker tests — **35/35 PASS**.
- Flutter visual/editor/save widget tests — **16/16 PASS**, including synthetic composition, repeated lifecycle events, failure/retry with no false acknowledgement.
- Encrypted Library/index navigation tests — **23/23 PASS**, including clean worker reopen and Telugu version history.
- Read-only recovery verdict tests — **5/5 PASS**.
- Android debug APK compiled and uploaded — **PASS**; Actions artifact ID `14105145504`, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

## Unverified / blocked

- **Actual Telugu Gboard and physical keyboard input**, native IME composition behavior, 200% font/accessibility, Android phone/tablet keyboard overlap and TalkBack.
- **New on-device background/reboot/force-stop test for this composition flow.** Existing unrelated fictional Android force-stop proofs do not automatically prove this change.
- Guaranteeing retention of **unacknowledged typing** after OS kill is not possible and must never be promised.
- Independent recovery-key custody, power-loss/OEM/low-storage, large media scale, security/privacy audit and complete signed production beta.
- Any actual personal diary writing is prohibited in the APK 02 fictional diagnostic.

## Next engineering task

Add an API-34 Android connected-editor diagnostic that drives **scripted fictional** Telugu composition and background/relaunch transitions, verifies only acknowledged versions, and fails closed on unfinished composition. Keep hardware/real input acceptance as a separate human physical-device gate. The approved A Still Pages + C Memory Atelier visuals and B Midnight Archive dark theme remain unchanged.
