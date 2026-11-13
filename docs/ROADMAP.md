# Roadmap — Navin Journal

**Current phase:** Stage 3 device/user signoff open. Stage 4 A2.4 native Keystore bridge, **A3.4 Android emulator force-stop/recovery**, A3 Linux autosave/SIGKILL **44/44**, and A4.1/A4.2 and A4.3.1/A4.3.2 full-schema archive tests **56/56 Linux tests** verified. **A3.3 Android editor lifecycle**, A4 real Android clean-device restore, full product vault, physical security and consumer APK remain **OPEN**.

## Stage 1 — Competitive review [DONE: research-only]

Studied Day One, Journey, Diarium, Apple Journal, Daylio, Grid Diary, stoic., Rosebud, Reflectly and Penzu; identified writing, long-term archiving, ownership, privacy and cross-device reliability as core opportunities. Product research is not a live user study.

## Stage 2 — Product blueprint [DONE: initial specification]

Product promise, P0/P1/P2 boundary, proposed navigation, data-trust contract and technical candidates documented. Security and usability validation still outstanding.

## Stage 3 — Visual identity and complete UX [ACTIVE]

- [x] Establish three directions: Still Pages / Midnight Archive / Memory Atelier.
- [x] Define four-destination information architecture and core writing/reading flows.
- [x] Select A Still Pages + C Memory Atelier, with B Midnight Archive as dark theme (user approved 2026-11-13).
- [x] Draft semantic color tokens, typography, grids, motion, iconography and responsive guidance.
- [x] Explore three original brand marks (Folded Page, Quiet Leaf, Memory Window); create vector source and responsive light/dark identity review. **52/52 Chromium checks passed** on [run 43393618241](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43393618241). See [brand QA report](QA_STAGE3_BRAND_2026-11-13.md).
- [x] Approve Folded Page (option 01) as primary visual mark (user approved 2026-11-13); integrate on Welcome, setup, sidebar and mobile header.
- [x] Prepare light/dark SVGs, 108dp adaptive layers, monochrome icon, Android VectorDrawable XML staging, and mask-review page. See [asset handoff](BRAND_ASSET_HANDOFF.md).
- [ ] Approve consumer-facing product name, wordmark, native icon export and final splash assets; confirm name availability.
- [ ] Compile staged launcher XML with AAPT2 and inspect adaptive/themed icon masks on physical Android devices (Stage 4 integration).
- [x] Specify 18 screens including critical empty/loading/error/permission states and all core journeys.
- [x] Author a standalone navigable HTML Stage 3 prototype: first-journal setup, sample writing/reading, journal-aware context, Memories/Search, simulated app-lock and backup/error states, light/dark and responsive tablet reader. Not a working diary.
- [x] Add connected in-memory journal creation, rename, archive/unarchive, entry/journal Trash, restoration, permanent-deletion confirmation and backup-state review. **80/80 browser checks passed** in [CI run 43400897845](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43400897845). See [UX Recovery Report](UX_RECOVERY_STAGE3.md). No persistent data or real backup.
- [x] Connect **writing → reading → editing → Trash → restoration** within one fictional in-memory journey; prevent unsaved sample draft loss via confirmation; fix mobile Writer nav overlap and improve Telugu screenshot fonts. **41/41 journey checks** passed, with **431/431 across all automated UX suites** in [CI run 43403054214](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43403054214). See [connected UX handoff](UX_CONNECTED_JOURNEY_STAGE3.md).
- [x] Fix initial JavaScript syntax bug and pass 20 mocked-DOM navigation/safety-state smoke checks.
- [x] Run actual Chromium navigation/render QA across 360/430/768/1024px: 90 checks passed and 24 screenshots generated (2026-11-13). Automated axe-core scan found no WCAG A/AA violations in seven sampled HTML screens. See [QA report](QA_STAGE3_2026-11-13.md).
- [x] Run extended Chromium large-text/bilingual UX checks: 84/84, across four viewport sizes, including 200% text reflow and Telugu–English/emoji. See [extended QA report](QA_STAGE3_EXTENDED_2026-11-13.md).
- [x] Add focus/keyboard checks: 33/33 passed across narrow phone and two tablet layouts, with skip link, active destination and modal isolation. See [run 43392361821](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43392361821).
- [x] Prepare [physical-device QA guide](DEVICE_UX_TEST_RUNBOOK.md) for Telugu IME, soft keyboard, screen readers and 200% text.
- [ ] Complete those checks on real devices and final visual/art review before closing Stage 3.
- [x] Exercise representative first-write, journal, recall, keyboard and theme flows with automated phone/tablet Chromium scripts.
- [ ] Validate with actual people and supported physical devices.
- [x] Record approved hybrid and draft design tokens in GitHub.
- [ ] User-test first-write, discovery, Trash, restore, theme parity and accessibility; resolve blockers.

## Stage 4 — Engineering proof of concept [ACTIVE; isolated tests only]

- [x] Build an **unencrypted Dart/SQLite reference store** with transactional journal/entry writes, stable IDs, previous revisions, explicit version conflict detection, event dates, archive/Trash and restore. **18/18 tests** and Dart analysis passed on Linux in [CI run 43405129229](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43405129229). Do not enter real diary data; this is neither autosave nor a secure vault. [Stage 4 report](STAGE4_ENGINEERING_SPIKE.md).
- [x] **A2 file-encryption feasibility (Linux only):** SQLite3MultipleCiphers with verified key handling, independent ordinary-SQLite rejection, test-sentinel checks in database/WAL, revision rollback and legacy-plaintext rejection. **13/13 encrypted tests passed** in [CI run 43408840728](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43408840728). See [A2 spike README](../spikes/encrypted_store/README.md).
- [x] **A2.2 key-envelope rotation protocol (Linux):** stage → verify → promote → finalize a replacement AES-GCM wrapping key while preserving the encrypted SQLite database key; failure injection, lost-key and tamper rejection. **14/14 tests passed** in [run 43410218147](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410218147). Uses a **software fake device protector**, not production device security. [Full report](../spikes/key_lifecycle/README.md).
- [x] **A2.2 staged Android Keystore source compiles:** Kotlin AES-GCM wrapper compiled against API 35 in [run 43410753987](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410753987). No Android runtime or Flutter integration.
- [x] **A2.3 Android emulator runtime:** real AndroidKeyStore provider exercised by **12/12 instrumented tests** on API 35; authenticated encryption, wrong AAD/tampered data, missing/retired aliases, wrapping key rewrap, non-exportability. [Passing run 43413956404](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956404) and [runtime QA report](STAGE4_A2_3_ANDROID_RUNTIME.md). **Not physical hardware, reboot/reinstall, or Flutter integration.**
- [x] **A2.4 Flutter Android native bridge:** Flutter static analysis, **14/14 MethodChannel contract tests**, SQLite3MultipleCiphers debug APK build and **2/2 real Android API-35 emulator integration tests** passed in [run 43416837265](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43416837265). Tests reopened a fictional encrypted database through Flutter→Kotlin→AndroidKeyStore, rotated wrapping key and rejected missing alias. [Engineering handoff](STAGE4_A2_4_FLUTTER_BRIDGE.md). Not a private journal app or physical hardware proof.
- [ ] **A2.4 production follow-up:** physical Android security, OS reboot/reinstall, key invalidation, concurrency-safe Flutter plugin lifecycle and independent recovery are still unverified.
- [ ] **A2 production key lifecycle/security gate:** physical Android Keystore hardware/runtime tests (emulator-only already passed), iOS Keychain parity, separate recoverable backup, key loss/reinstall/reboot handling, authenticated metadata hardening, attachment/index/cache protection, device build and independent security review. Linux fake-provider tests and source compilation **do not** meet this gate.
- [x] **A3.1/A3.2 autosave baseline:** Debounced editor save-state coordinator, IME composition handling, failure/retry/conflict states, encrypted SQLite title+body commit history, transaction fault rollback, and idempotent retry after a lost acknowledgement. **33/33 Dart tests passed** on Linux in [run 43420715468](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43420715468). [A3 report](../spikes/autosave_coordinator/README.md). Test fixtures only; not a production editor.
- [x] **A3.3 background encrypted storage worker — Linux verified:** one Dart isolate owns encrypted SQLite and serializes write/read operations off the Flutter UI isolate. **41/41 A3 suite tests** (including 8 worker tests) passed in [run 43421552880](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43421552880).
- [ ] **A3.3 Android Flutter editor lifecycle:** debug-only fictional entry UI implemented, with save status, Android lifecycle flush requests and explicit encrypted reopen; [Earlier CI run 43422522118](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43422522118) failed at emulator Android package-manager installation (not a failing journal assertion); [new CI workflow](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/flutter-keystore-bridge.yml) adds a readiness gate and sequential suites. Emulator runtime proof remains open. [QA report](STAGE4_A3_3_ANDROID_EDITOR.md).
- [x] **A3.4 Linux OS-kill feasibility:** actual SIGKILL of separate SQLite writer **inside transaction**, **after COMMIT before ACK**, and **after ACK**; encrypted WAL recovery and idempotent retry verified. **44/44 A3 tests passed** in [run 43425363790](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43425363790). [A3.4 report](STAGE4_A3_4_CRASH_RECOVERY.md).
- [x] **A3.4 Android force-stop/relaunch runtime proof:** [run 43427287021](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43427287021) passed on API-35 emulator: **ACK_V1 → actual ADB force-stop → ACK_V2 → actual ADB force-stop → RECOVERED_V2**, with original AndroidKeyStore wrapping key and app-private encrypted SQLite database preserved. [QA report](STAGE4_A3_4_ANDROID_FORCE_STOP.md). This is not a power-loss/reinstall/physical-device test.
- [ ] **A3.4 Android release-hardening after emulator proof:** complete physical-phone ADB force-stop/relaunch, reboot, real Telugu IME, low storage and recovery of all acknowledged versions; unify journal schema. **No claim that unsaved typing survives OS kill.**
- [ ] Test attachment import atomically; verify error behavior for malformed media and full storage.
- [x] **A4.1 portable encrypted archive verification — Linux proof:** AES-256-GCM container with a separate user-held random 256-bit recovery key, encrypted Telugu/English entries and attachments, SHA-256 media hashes, key/tamper/format/path/size refusal. **16/16 tests passed** in [run 43430251517](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43430251517). [A4.1 report](../spikes/recovery_archive/README.md). Test-only verify/preview; no destination writes, production key recovery or actual database backup.
- [x] **A4.2 staged encrypted clean-vault restore — Linux proof:** archive authenticated before staging, newly encrypted SQLite3MultipleCiphers entries/media committed as one transaction, independently reopened and byte/hash checked, then published to a new directory only. Wrong keys/tampering, seven injected faults, late collision and existing destination all rejected without intentional overwrite. **34/34 A4 suite tests passed** in [run 43433845516](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43433845516). [A4.2 QA](STAGE4_A4_2_CLEAN_RESTORE.md).
- [x] **A4.3.1 logical whole-journal contract — Linux verified:** preserve journals, archived/trashed state, entry event/write timestamps, exact prior revisions, journal moves and authenticated media references; reject missing/duplicate links, corrupt digests, bad versions and unsafe paths. **15 new tests passed**. This is a plaintext in-memory structure only; NEVER write it as a backup.
- [x] **A4.3.2 independent-key full-schema archive — Linux verified:** AES-256-GCM version-2 container with a separate offline recovery key; tampering, wrong key, legacy-format confusion and invalid source structures fail closed. **7 additional tests passed**, bringing the combined A4 suite to **56/56** in [CI run 43437013666](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43437013666). [A4.3 report](STAGE4_A4_3_PRODUCT_ARCHIVE.md). No real database snapshot, v2 restore, Android device, power-loss or private-data readiness.
- [x] **A4.3.3 whole-journal encrypted core and transactionally consistent v2 export — Linux test verified:** shared package supports encrypted journal/entry CRUD, version history, Trash, media, independent key reopening, fail-closed conflicts and consistent WAL snapshot under concurrent writer; 12 initial integration tests passed. All data fictional and no UI integration.
- [x] **A4.3.4a whole-schema v2 staged clean-vault restore — Linux test verified:** authenticate before staging, import all journals/revisions/Trash/media in one encrypted transaction, independently reopen/compare and publish to a NEW destination. Wrong keys, tampering, occupied/late-collision targets and nine rollback fault points tested. **21/21 combined journal_core tests passed** in [run 43444827657](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43444827657). [APK02 core handoff](STAGE5_APK02_CORE_HANDOFF.md). **NOT production restore**: no native no-replace/fsync or real Android device proof.
- [ ] **A4.3.4b–A4.3.5 production durability and clean Android restore:** add race-free no-clobber, durable fsync/migrations/disk-full/power-loss, scalable chunked media, complete device key custody, real Flutter editor integration, fresh Android reinstall restore with only separate recovery key, security and hardware verification.
- [ ] Validate Flutter + native editor accessibility/performance alternatives and Android build viability.
- [ ] Threat-model lock/key handling, caches, exports and migration, with appropriate independent review.
- [ ] Decide sync backend, cost ceiling and cross-platform build plan.

## Stage 5 — Functional build [APK 01 DONE; SHARED CORE BUILT; FUNCTIONAL UI NOT CONNECTED]

- [x] **APK 01 · visual-only Flutter walkthrough:** approved A+C / Midnight Archive theme, Folded Page emblem, welcome/setup, Today, Journals, Reader, demo Writing Studio, Memories, Discover, Settings, simulated recovery/Trash. **6/6 Flutter phone/tablet widget tests passed, Android debug APK compiled and artifact uploaded** in [run 43441554960](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43441554960). Debug-only fictional sample content, **no persistence, app lock, real media, vault, autosave, backup or private-data security**. [Preview source and limitations](../preview_app/README.md). APK SHA-256: `c0f3b4923bcc69780f16271cb673976fe8717eb852c8d38fad636c5216367107`. Physical handset/tablet and adaptive-mask review pending.
- [x] **APK 02 shared core vertical slice — Linux verified only:** complete schema, CRUD/edit history, Trash, encrypted media, consistent v2 export and independent empty-vault restore. **21/21 tests passed**; this is reusable engine code, not linked to the Android UI. [Handoff](STAGE5_APK02_CORE_HANDOFF.md).
- [ ] **APK 02 Android writer diagnostic — IN VALIDATION:** [Flutter debug Writing Studio](../preview_app/lib/apk02_probe_main.dart) uses approved Folded Page visuals, existing AndroidKeyStore wrapper and background Dart isolate to write/reopen fictional journal core v1/v2. Static analysis, existing 6 UI widget tests and debug Android APK compilation passed in [run 43447323791](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43447323791); real API-35 ADB force-stop/relaunch evidence remains **pending** until emulator run finishes. [Diagnostic engineering notes](STAGE5_APK02_ANDROID_WRITER.md). Not a beta for private user writing.
- [ ] **APK 02 · functional private beta:** do not enable real personal writing until encrypted whole-journal storage, autosave, independent backup/clean-device recovery and critical security gates are met.

- [ ] Write/edit/versions/drafts, journals, search, calendar/timeline.
- [ ] Media blocks, readable export, accessibility, personalization.
- [ ] Backup/restore and Trash production-quality.
- [ ] Only then optional cloud sync and selected differentiators.

## Stage 6 — Reliability, security and release [NOT STARTED]

- [ ] Fault-injection, device migration and Unicode testing.
- [ ] Real device and tablet UX validation.
- [ ] Security/privacy review and third-party dependency review.
- [ ] Signed reproducible build, restore verification and release checklist.

## Change control

Do not change requirements, add features, declare tests passed or claim APK readiness without evidence. Log decisions and trade-offs in the decision register. A visually approved mockup is not functional implementation.
