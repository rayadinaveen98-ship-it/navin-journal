# APK 02 — Read-only Restore Safety navigation

**Status:** implemented in the fictional APK 02 Library and **seven real-worker Flutter navigation tests passed** in [run 43566554486](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43566554486). A standalone Android debug APK compilation is a separate gate. No personal data entry, backup restore action, or deletion is enabled.

## User flow

**Fictional Library → Review restore safety → Restore Safety → Back to Library.**

- The Library now includes a visually consistent **Review restore safety** entry, available only when the app has an explicit private-root directory.
- In the Android diagnostic, this private root comes from the existing Android native `getPrivateRoot` bridge. The screen does a bounded, **read-only** `RestoreStagingInventory.inspect`; only the count is shown, not filenames, paths, titles, journal text or keys.
- An empty private root displays **No interrupted restore folders detected**. Any candidate only indicates a *possibly interrupted* folder. It is not authenticated by a name, SQLite file or marker.
- **The actual APK has no archive/key custody UI and therefore never enables a Verify action**. If a candidate exists, the screen states that the separately retained backup and staging key are unavailable and **does not** offer recovery, cleanup or deletion.
- The optional `authenticatedAssessment` callback is intentionally **fictional test-only**. In test fixtures with an independently encrypted archive, a real background-worker assessment returns counts and an authenticated verdict. Even a match stays quarantined. The interface provides no recovery/deletion action.
- The user can safely return to Library and continue using the existing scripted fictional editor. No modifications to the Writing Studio, active encrypted journal or theme were required.

## Engineering evidence

[Real-worker Flutter navigation CI 43566554486](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43566554486) passed **7/7 tests**, including:

1. Existing empty encrypted Library → Writing Studio → scripted save.
2. Reader → edit, revision history and encrypted reopen.
3. Library reload after encrypted worker close/reopen.
4. Narrow phone and tablet Library rendering.
5. Library → Restore Safety empty scan → rescan → back to Library, without modifications.
6. Unknown interrupted staging folder shown **without** providing authentication, destructive action, or a path. The orphan is byte-for-byte unchanged.
7. A genuine encrypted stage built from fictional history is authenticated by the actual `PortableRecoveryWorker`, then its verdict shown in a navigable review; the stage is not published or erased, and the Library remains usable.

The Flutter test harness precomputes real native inventory and cryptographic results **outside Flutter fake time** and injects them into view state. This tests navigation and presentation deterministically, while the independent [41/41 core assessment run](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43564506990) and [35/35 worker assessment run](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43564673309) test actual file inspection, authentication, and isolate transport.

This distinction is important: **a successful widget test is not the same as physical Android verification of an authenticated recovery screen**.

## Still outstanding

Full user-facing recovery and/or discard decisions require independent secure key custody, authenticated original stage ownership, safe filesystem lock/lease semantics, explicit user confirmation, crash/power-loss/low-storage trials on real Android hardware, and security review. None is implicitly unlocked by a matched assessment. Automatic cleanup of unknown staging paths remains forbidden.

**Do not enter personal journal content into any APK 02 diagnostic build.**
