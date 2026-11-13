# Roadmap — Navin Journal

**Current phase:** Stage 3, in progress; approved visual direction and detailed UX documents committed. No production journaling app or APK yet. A navigable HTML UX prototype has automated browser checks.

## Stage 1 — Competitive review [DONE: research-only]

Studied Day One, Journey, Diarium, Apple Journal, Daylio, Grid Diary, stoic., Rosebud, Reflectly and Penzu; identified writing, long-term archiving, ownership, privacy and cross-device reliability as core opportunities. Product research is not a live user study.

## Stage 2 — Product blueprint [DONE: initial specification]

Product promise, P0/P1/P2 boundary, proposed navigation, data-trust contract and technical candidates documented. Security and usability validation still outstanding.

## Stage 3 — Visual identity and complete UX [ACTIVE]

- [x] Establish three directions: Still Pages / Midnight Archive / Memory Atelier.
- [x] Define four-destination information architecture and core writing/reading flows.
- [x] Select A Still Pages + C Memory Atelier, with B Midnight Archive as dark theme (user approved 2026-11-13).
- [x] Draft semantic color tokens, typography, grids, motion, iconography and responsive guidance.
- [ ] Approve consumer-facing brand name and final logo.
- [x] Specify 18 screens including critical empty/loading/error/permission states and all core journeys.
- [x] Author a standalone navigable HTML Stage 3 prototype: first-journal setup, sample writing/reading, journal-aware context, Memories/Search, simulated app-lock and backup/error states, light/dark and responsive tablet reader. Not a working diary.
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

## Stage 4 — Engineering proof of concept [NOT STARTED]

- [ ] Validate Flutter + editor accessibility/performance alternatives.
- [ ] Test encrypted local database, attachment import, durable writing.
- [ ] Demonstrate backup archive creation and restore on clean device.
- [ ] Threat-model lock/key handling, caches, exports.
- [ ] Decide sync backend, cost ceiling and cross-platform build plan.

## Stage 5 — Functional build [NOT STARTED]

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
