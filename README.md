# Navin Journal

**Status:** Product pre-production — Stage 3 (approved visual direction; detailed UX specified; validation pending).  
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
- [Design system and semantic tokens](docs/DESIGN_SYSTEM_V1.md)
- [Full screen specification](docs/SCREEN_SPECIFICATION_V1.md)
- [Interaction contracts and critical states](docs/INTERACTION_CONTRACTS_V1.md)
- [UX validation matrix](docs/UX_VALIDATION_MATRIX.md)
- [Physical-device UX, Telugu IME and screen-reader test guide](docs/DEVICE_UX_TEST_RUNBOOK.md)
- [Stage 3 Chromium QA report (13 Nov 2026)](docs/QA_STAGE3_2026-11-13.md)
- [Stage 3 extended 200% type/Telugu UX QA](docs/QA_STAGE3_EXTENDED_2026-11-13.md)
- [Stage 3 navigable design preview](prototype/stage3-ux-preview.html) (sample content; no real storage or security)
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
