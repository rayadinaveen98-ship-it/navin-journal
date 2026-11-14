# Decision register

| ID | Decision or proposal | State | Rationale / next action |
|----|----------------------|-------|-------------------------|
| NJ-001 | Standalone pure journaling app, not part of Backlot or EVOLUNE | Confirmed scope | Preserve clarity and quality |
| NJ-002 | Internal project name = Navin Journal | Provisional | Consumer brand must be selected separately |
| NJ-003 | Local-first offline writing; account not required for first entry | Proposed baseline | Validate onboarding and key model |
| NJ-004 | Four destinations: Today / Journals / Memories / Discover | Proposed baseline | Test with representative tasks |
| NJ-005 | Separate journals as first-class objects | Proposed baseline | Competitor differentiation and organization |
| NJ-006 | Strong data recovery, exports, revisions, Trash, no silent overwrites | Required product principle | Test and specify before implementation |
| NJ-007 | A Still Pages + C Memory Atelier as primary; B Midnight Archive as dark theme | APPROVED 2026-11-13 | Editor stays restrained; memories use photo-led surfaces; dark theme retains interaction parity |
| NJ-008 | Flutter for shared Android/iOS/Windows application | Candidate, not approved | Prove editor, accessibility, privacy and build viability |
| NJ-009 | Optional encrypted sync | Future design, not approved | Determine cost/security model, zero surprise charges |
| NJ-010 | Recurring payment only for recurring service costs | Proposed | Market and feasibility validation needed |
| NJ-011 | AI never required to write, read or export journals | Required product principle | Any AI optional and explicit opt-in |
| NJ-012 | No production implementation until visual target and P0 specifications are approved | Active Stage-3 gate | Visual concept approved; UX validation and final P0 engineering acceptance remain open |

| NJ-013 | Four-tab UX and the 18-screen detailed specification | DRAFTED 2026-11-13 | Requires usability and accessibility validation before sign-off |
| NJ-014 | Light/dark semantic design tokens, type and spacing | DRAFTED 2026-11-13 | Proposed values contrast-checked in principle; actual component/device review pending |

| NJ-015 | F1 Folded Page approved as primary visual mark | APPROVED 2026-11-13 | User selected “01”; retain A + C visual language and B dark theme. Final consumer name, legal availability and production launcher QA remain open |
| NJ-016 | Connected Journal Management/Trash/Recovery UX | DESIGN-VALIDATED 2026-11-13 | Simulated create/rename/archive/delete/restore, explicit orphan destination, fake backup states; 80 Chromium checks passed; no real storage or recovery engine |
| NJ-017 | Stage 3 connected writing/recovery UX | DESIGN-VALIDATED 2026-11-13 | Fictional write/edit/discard/delete/restore flows pass 41 Chromium checks; mobile Writer nav overlap fixed; no production autosave/storage or security |
| NJ-018 | Stage 4 A1 isolated unencrypted SQLite reference store | TESTED 2026-11-13 | 18/18 Linux Dart tests passed; confirms transaction/revision model only, not production engine, encryption, autosave or Flutter stack |
| NJ-019 | Stage 4 A2 encrypted-file research implementation using SQLite3MultipleCiphers | LINUX FEASIBILITY TESTED 2026-11-13 | 13/13 tests pass; verify wrong/no key, encrypted revision, legacy file rejection; NOT a production key provider, Android vault or approved security architecture |
| NJ-020 | A2.2 staged wrapping-key protocol and Android Keystore adapter | LINUX PROTOCOL TESTED + ANDROID SOURCE COMPILED 2026-11-13 | 14/14 test-double+encrypted SQLite checks passed; Kotlin API35 compile passed. Native runtime, recovery, app binding and security approval remain open |
| NJ-021 | A2.3 real AndroidKeyStore emulator runtime validation | EMULATOR TESTED 2026-11-13 | 12/12 AndroidJUnit4 API35 tests passed; validates Android framework provider in emulator, NOT hardware-backed physical device, Flutter bridge, recovery or release security gate |
| NJ-022 | A2.4 Flutter MethodChannel to Android Keystore | EMULATOR TESTED 2026-11-13 | 14 contract tests and 2 full native Android emulator integration tests passed, debug APK built; NOT physical-device security or production journaling UI |
| NJ-023 | A3 autosave-state coordinator plus encrypted transaction experiment | LINUX TESTED 2026-11-13 | 33/33 tests passed; separates pending vs acknowledged writes, prevents stale overwrite, handles lost ACK, transaction rollback and SQLite reopen; Android lifecycle and unified product vault remain pending |
| NJ-024 | Stage 4 A3.3 one-owner encrypted SQLite isolate and diagnostic Flutter editor | LINUX STORAGE TESTED 2026-11-13 | 41/41 Dart tests pass; Android debug writer/lifecycle checks pending CI; not physical-device crash-safe autosave, user diary or final visual design |
| NJ-025 | Stage 4 A3.4 encrypted WAL recovery after real Linux SIGKILL | LINUX PROCESS-KILL TESTED 2026-11-13 | 44/44 total A3 checks passed including midtransaction rollback, post-COMMIT lost ACK and post-ACK recovery; Android ADB force-stop, restart and physical phone remain OPEN |
| NJ-026 | A4.1 independent random recovery-key authenticated portable archive | LINUX TESTED 2026-11-13 | 16/16 Dart tests passed for AES-256-GCM verify-only fictional export, tamper, schema and path limits. NOT a password KDF, production backup, clean-device restore or release-security claim |
| NJ-027 | Android A3.4 force-stop survival of acknowledged fictional encrypted entries | ANDROID EMULATOR TESTED 2026-11-13 | Verified run 43427287021: ACK_V1 / force-stop / ACK_V2 / force-stop / RECOVERED_V2 with same app-private database and AndroidKeyStore key; physical phone/reinstall and A3.3 editor pending |
| NJ-028 | A4.2 authenticated archive staged restoration to new encrypted SQLite vault | LINUX TESTED 2026-11-13 | 34/34 A4 tests passed, including 18 staged import/fault/collision/byte-verification cases; fictional schema only, no true clean-device Android recovery or security approval |
| NJ-029 | Reversible per-page encrypted Trash/restore, exact expected version and journal ownership | VERIFIED FICTIONAL APK02 2026-11-14 | Reader requires confirmation, worker refuses cross-journal/stale/archived actions, restore preserves ID and revisions; 26/26 Library tests and Android APK built in run 43577505729, native regression run 43577505674 passed. No permanent delete or private-data beta approval. |

| NJ-030 | Fictional encrypted export/clean-vault recovery rehearsal in existing Restore Safety UX | DEBUG VERIFIED 2026-11-14; NOT RECOVERABLE BACKUP | 37/37 worker and 28/28 Library tests pass; Android debug APK and API34 native regression pass in runs 43579984505 and 43579984540. It uses ephemeral keys and a throwaway encrypted vault, never exports a user-retained archive, never touches the existing vault, and must never be described as off-device recovery. Real key custody/SAF/clean-device proof and security gate remain open. |

| NJ-031 | Android user-selected fictional encrypted archive export + separate manual recovery key | APK02 ENGINEERING VERIFIED 2026-11-14; OFF-DEVICE RECOVERY STILL OPEN | ACTION_CREATE_DOCUMENT writes v2 AES-GCM ciphertext; native provider readback checks length/SHA-256 before FLAG_SECURE and ephemeral key display. 41/41 worker tests and 29/29 Library integration tests, Android APK build and API34 regression passed (43581837392/43581837391). Off-device key custody, physical SAF picker and clean-device document import/restore remain unproven; private-data beta blocked. |

| NJ-032 | Fictional Android SAF archive import with manually re-entered recovery key and disposable clean-vault inspection | ENGINEERING VERIFIED 2026-11-14; NOT DURABLE RESTORE | Bounded ACTION_OPEN_DOCUMENT input, FLAG_SECURE masked key, real v2 AES-GCM restore into isolated temporary encrypted vault, independent reopen/checks; wrong key/tampering/cancel fail closed. 45/45 worker, 30/30 Library, Android APK and API-34 regression pass (43583688287/43583688293). No persistent new-device key envelope, activation, physical picker proof or private-data beta signoff. |

| NJ-033 | Separate retained encrypted recovery candidate, never silent active-vault replacement | ENGINEERING VERIFIED 2026-11-14; NATIVE CANDIDATE/HARDWARE OPEN | A fresh device-wrapped key/envelope and atomic no-replace child vault allow offline candidate reopen; permanent exclusive-create reservation serializes imports and preserves interrupted candidates without reset. 52/52 worker, 31/31 Library/widget, debug Android build and baseline API34 lifecycle passed (43587076593 / 43587076581). At PR #10 this evidence was limited to a Linux insecure fake protector; PR #11 subsequently verified actual AndroidKeystore API34 runtime, not physical hardware. Durable activation, key-loss handling, power-loss, device QA, private beta are blocked. |

| NJ-034 | Stage 5A actual AndroidKeystore retained-vault runtime proof, separate from durable activation | ANDROID API34 EMULATOR VERIFIED 2026-11-14; USER/PHYSICAL RELEASE BLOCKED | PR #11 and passing run 43589135432 prove external fictional archive/key → original app uninstall/reinstall → distinct native Keystore-protected retained candidate → no original input → Android force-stop/reopen with exact Telugu/history → retire candidate alias → fail closed without deleting encrypted files or harming separate journal. Existing API34 baseline 43589135396 and Library 43589135387 also pass. The new key-delivery used an ADB diagnostic, NOT Android SAF picker/manual key entry; actual physical OEM hardware, crash-safe user-approved candidate activation, security audit and private-data beta remain unverified. |

## Pending high-impact decisions

- Final consumer brand name, trademark/availability review and production launcher/splash approval; Folded Page direction approved.
- Android-first validation vs simultaneous platform support.
- Precise encrypted backup recovery process and key handling.
- Minimal P0 inline media set.
- Which advanced memory features (if any) qualify for first public release.
- Pricing and zero-spend development constraints.
