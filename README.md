# Navin Journal

**Status:** Stage 3 physical-device/user signoff remains open. Stage 4 isolated A1 transaction, A2 encrypted-file and A2.2 device-key lifecycle *protocol* proofs have passing Linux tests; Android Keystore adapter compiles and passed 12/12 API-35 emulator runtime tests. No production journaling app, physical-device security validation, verified backup or APK.  
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
- [Stage 3 navigable design preview](prototype/stage3-ux-preview.html) (sample content; no real storage or security)
- [Connected journal management & recovery UX preview](prototype/journal-recovery-review.html) (fictional examples, in-memory only)
- [Journal and recovery UX validation report](docs/UX_RECOVERY_STAGE3.md)
- [Connected writing-to-recovery Stage 3 handoff](docs/UX_CONNECTED_JOURNEY_STAGE3.md)
- [Stage 4 engineering spike (A1 tested, encryption pending)](docs/STAGE4_ENGINEERING_SPIKE.md)
- [Dart SQLite transaction reference package](spikes/offline_store/README.md) (fictional data only)
- [Encrypted SQLite3MultipleCiphers feasibility spike](spikes/encrypted_store/README.md) (13 Linux tests; fictional data; not a production secure vault)
- [Device key-envelope lifecycle spike](spikes/key_lifecycle/README.md) (14 Linux protocol tests and 12 Android emulator tests; physical-device gate open)
- [Android Keystore API-35 emulator QA report](docs/STAGE4_A2_3_ANDROID_RUNTIME.md)
- [Stage 3 brand comparison preview](prototype/brand-study.html) (option 01 Folded Page selected)
- [Adaptive launcher-mask visual review](prototype/brand/adaptive-preview.html) (design-only)
- [Prototype usage and limits](prototype/README.md)
- [Mocked-DOM smoke tests](prototype/tests/smoke.mjs)
- [Data, security and reliability](docs/DATA_PRIVACY_RELIABILITY.md)
- [Acceptance criteria](docs/ACCEPTANCE_CRITERIA.md)
- [Roadmap](docs/ROADMAP.md)
- [Decision register](docs/DECISION_REGISTER.md)

## Current constraints

No source code, APK, server or live prototype is represented as complete in this repository initialization. No paid infrastructure may be provisioned without an explicit decision and a cost assessment. Avoid vendor lock-in, unreviewed AI access to journal content, and irreversible data formats.

## Next gate

Review the approved A + C light experience and B dark theme in phone/tablet mockups, validate full UX with representative users, approve consumer branding, and ratify data-loss and backup requirements before implementing the first vertical slice.
