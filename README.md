# Navin Journal

**Status:** Stage 3 physical-device/user signoff is open. Stage 4 A2.4 Flutter→Android Keystore→encrypted SQLite proof passed 14 Flutter contract and 2 Android emulator integration tests. A3.1–A3.4 state-machine, encrypted SQLite transaction, off-main-isolate and OS-kill tests passed **44 Linux tests (including three real SIGKILL recovery checks)**. A3.4 **Android emulator force-stop/relaunch recovery passed** across two acknowledged fictional versions. A4.1–A4.3.2 authenticated archive, staged restore and complete logical snapshot encryption passed **56 Linux tests**. **APK 01 visual-only Flutter preview built with 6/6 widget checks**. APK 02 shared whole-journal encrypted core (CRUD, revisions, Trash, media, consistent v2 export, full-schema staged restore) passed **21/21 Linux tests** in [run 43444827657](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43444827657). **An experimental Flutter Library/Reader/Writer diagnostic now connects to the encrypted core**. It compiled as a separate **fictional-data-only APK** after 23/23 editor-worker and 13/13 stable Flutter widget tests passed in [run 43457857948](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43457857948). **A separate Android API-34 connected-editor/Keystore recovery test passed** all three actual stages (ACK_V1 → ACK_V2 → RECOVERED_V2) after two real force-stops in [run 43479108180](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43479108180). **A separate fictional API-34 Android clean-uninstall/reinstall recovery proof also passed** all four steps (off-device archive export, wrong-key refusal, new Keystore restore, and post-force-stop reopen of v2 plus historical v1) in [run 43558301280](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43558301280), alongside **29/29 encrypted recovery and 13/13 Flutter tests**. The Library app UI still needs hardware testing, and **no real private diary use is approved until production-durable backup/restore, native crash/no-overwrite safety, secure recovery-key UX and remaining privacy/security gates pass.**  
**Project name:** Navin Journal is the internal working title, not the approved consumer brand.  
**Repository:** `rayadinaveen98-ship-it/navin-journal`

## Vision

A private home for life's stories: effortless to write, meaningful to revisit, and engineered to preserve memories across years and devices.

This is a **pure journaling application**. It is intentionally separate from productivity tools, habit trackers, social networks, and wellness platforms.

## Product principles

1. **Writing comes first.** A distraction-free page is always one action away.
2. **Local-first.** Writing and reading must work without network access or an account.
3. **Trust is visible.** Save, backup, sync and restore status must be understandable.
4. **Depth without clutter.** Advanced features are progressive, never mandatory.
5. **Revisiting matters.** Reading, searching and exploring memories are first-class.
6. **Own your archive.** Users can export their entries and attached media using documented formats.
7. **Platform consistency.** Core data semantics and behaviors are the same across supported devices.

## Latest engineering slice — APK 02

- [Shared encrypted journal core](packages/journal_core/README.md) — 21/21 Linux test cases, verified create/edit/close/reopen, version history, Trash, media, transactional snapshot and encrypted clean-vault restore using fictional data.
- [Shared encrypted editor and isolate worker](packages/journal_editor/README.md) — **22/22 Linux integration tests**, reuses tested autosave save-state/IME logic; connects editor drafts to full encrypted journal schema via a background Dart isolate. **Android consumer UI connection and private-data beta are still open.**
- [Stage 5 / APK 02 safety handoff](docs/STAGE5_APK02_CORE_HANDOFF.md) — exact completed scope, remaining Android/editor/key/durability gates. **No production APK 02 yet.**

- [APK 02 fictional Library debug](docs/APK02_FICTIONAL_LIBRARY_VERTICAL.md) — installable debug diagnostic artifact from [successful CI run 43457857948](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43457857948). 23 encrypted worker tests + 13 stable Flutter widget tests passed; APK SHA-256 `da678c40cd8cf621e1211b362d3678cc2856d00d5678ea1795b54bf1eb31f6cd`. **No personal journal data allowed.**

## Working release strategy

- **P0:** reliable editor, entries/journals, search, local encryption, drafts, revision/Trash, verified backup/restore, accessible responsive layouts, import/export.
- **P1:** richer inline media and handwriting, timelines and galleries, advanced search, personalization, optional encrypted sync.
- **P2:** Life Chapters, Memory Trails, Then & Now, future letters, optional privacy-preserving assistance.

These are priorities, **not delivered functionality**. Product and technical decisions require validation.

## Read first

- [Product brief](docs/PRODUCT_BRIEF.md)
- [Experience architecture](docs/EXPERIENCE_ARCHITECTURE.md)
- [Approved visual direction](docs/VISUAL_DIRECTIONS.md)
- [Approved Folded Page mark and remaining brand candidates](docs/BRAND_STUDY.md)
- [Folded Page asset and Android staging handoff](docs/BRAND_ASSET_HANDOFF.md)
- [Brand review findings and browser QA](docs/QA_STAGE3_BRAND_2026-11-13.md)
- [Design system and semantic tokens](docs/DESIGN_SYSTEM_V1.md)
- [Full screen specification](docs/SCREEN_SPECIFICATION_V1.md)
- [Interaction contracts and critical states](docs/INTERACTION_CONTRACTS_V1.md)
- [UX validation matrix](docs/UX_VALIDATION_MATRIX.md)
- [Physical-device UX, Telugu IME and screen-reader test guide](docs/DEVICE_UX_TEST_RUNBOOK.md)
- [Stage 3 Chromium QA report (13 Nov 2026)](docs/QA_STAGE3_2026-11-13.md)
- [Stage 3 extended 200% type/Telugu UX QA](docs/QA_STAGE3_EXTENDED_2026-11-13.md)
- [APK 01 native Flutter visual preview](preview_app/README.md) — **6/6 widget checks and Android debug build passed** in [CI run 43441554960](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43441554960). Fictional entries only, no saving or user data security.
- [Stage 3 navigable design preview](prototype/stage3-ux-preview.html) (sample content; no real storage or security)
- [Connected journal management & recovery UX preview](prototype/journal-recovery-review.html) (fictional examples, in-memory only)
- [Journal and recovery UX validation report](docs/UX_RECOVERY_STAGE3.md)
- [Connected writing-to-recovery Stage 3 handoff](docs/UX_CONNECTED_JOURNEY_STAGE3.md)
- [Stage 4 engineering spike (A1–A3 Linux/emulator feasibility evidence)](docs/STAGE4_ENGINEERING_SPIKE.md)
- [Dart SQLite transaction reference package](spikes/offline_store/README.md) (fictional data only)
- [Encrypted SQLite3MultipleCiphers feasibility spike](spikes/encrypted_store/README.md) (13 Linux tests; fictional data; not a production secure vault)
- [Device key-envelope lifecycle spike](spikes/key_lifecycle/README.md) (14 Linux protocol tests and 12 Android emulator tests; physical-device gate open)
- [Android Keystore API-35 emulator QA report](docs/STAGE4_A2_3_ANDROID_RUNTIME.md)
- [A2.4 Flutter-to-AndroidKeyStore probe](spikes/flutter_bridge_probe/README.md) (14 Flutter channel + 2 Android emulator integration checks passed; still test-only)
- [A2.4 engineering handoff](docs/STAGE4_A2_4_FLUTTER_BRIDGE.md)
- [A3 autosave + encrypted background worker](spikes/autosave_coordinator/README.md) (**44 Linux tests passed**, including 3 actual SIGKILL checks; Android editor lifecycle validation pending)
- [A3.3 Flutter diagnostic editor and acceptance report](docs/STAGE4_A3_3_ANDROID_EDITOR.md)
- [A3.4 Linux crash/kill recovery evidence](docs/STAGE4_A3_4_CRASH_RECOVERY.md) (three OS SIGKILL checks; Android force-stop remains open)
- [A3.4 Android ADB force-stop/relaunch test harness](docs/STAGE4_A3_4_ANDROID_FORCE_STOP.md) (dedicated debug-only emulator fixture; runtime verification open)
- [A4.1/A4.2 independently recoverable encrypted archive and clean-vault restore](spikes/recovery_archive/README.md) (**34/34 Linux tests passed**; test-only new-vault restoration)
- [A4.2 verified staged restore and outstanding security gates](docs/STAGE4_A4_2_CLEAN_RESTORE.md)
- [A4.3.1/A4.3.2 whole-journal logical snapshot and encrypted v2 archive](docs/STAGE4_A4_3_PRODUCT_ARCHIVE.md) (**56/56 combined A4 Linux tests passed**; no production live-vault export or Android v2 restore)
- [Stage 3 brand comparison preview](prototype/brand-study.html) (option 01 Folded Page selected)
- [Adaptive launcher-mask visual review](prototype/brand/adaptive-preview.html) (design-only)
- [Prototype usage and limits](prototype/README.md)
- [Mocked-DOM smoke tests](prototype/tests/smoke.mjs)
- [Data, security and reliability](docs/DATA_PRIVACY_RELIABILITY.md)
- [Acceptance criteria](docs/ACCEPTANCE_CRITERIA.md)
- [Roadmap](docs/ROADMAP.md)
- [Decision register](docs/DECISION_REGISTER.md)

## Current constraints

Engineering spike source and diagnostic Android debug builds exist; no production journal app, signed release APK, secure backup or live server is represented as complete. No paid infrastructure may be provisioned without an explicit decision and a cost assessment. Avoid vendor lock-in, unreviewed AI access to journal content, and irreversible data formats.

## Next gate

Review the approved A + C light experience and B dark theme in phone/tablet mockups, validate full UX with representative users, approve consumer branding, and ratify data-loss and backup requirements before implementing the first vertical slice.
