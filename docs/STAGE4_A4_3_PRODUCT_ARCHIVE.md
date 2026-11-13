# Stage 4 A4.3.1–A4.3.2 — Whole-journal snapshot contract and encrypted archive

**Status (13 November 2026): Linux test-only evidence verified; A4.3 production recovery OPEN.**

**CI:** [GitHub Actions run 43437013666](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43437013666) — **56/56 tests passed**, including the earlier 34 A4.1/A4.2 cases and **22 new cases** (15 logical snapshot, 7 independently encrypted archive). Dart analysis passed.

## What changed

- [Logical whole-journal snapshot contract](../spikes/recovery_archive/lib/product_snapshot.dart) (NJR-PRODUCT-SNAPSHOT-1) validates journals and IDs, archive/Trash flags, original event/write timestamps, current entry versions, **contiguous historical revisions**, prior journal references, attached media links, safe filenames and SHA-256 media digests. This test-only codec encodes **plaintext in-memory JSON**, which must **never** be written as a backup.
- [Independent-key encrypted archive v2](../spikes/recovery_archive/lib/product_encrypted_archive.dart) (NJR-RECOVERY-2) AES-256-GCM encrypts the full validated snapshot with the separate A4.1 256-bit recovery key. The outer container contains only format/algorithm, nonce, ciphertext and authentication tag; its AAD domain is version-separated from A4.1. Incorrect keys, tampering, metadata additions and legacy format confusion are refused.
- [15 schema tests](../spikes/recovery_archive/test/product_snapshot_test.dart) cover Telugu/English/emoji, journal moves, revisions, Trash, media, broken references, wrong types, timestamps, duplicate IDs and bounded payloads.
- [7 encrypted-v2 tests](../spikes/recovery_archive/test/product_encrypted_archive_test.dart) cover content round-trip, absence of sample plaintext in outer archive, key independence, tampering, format downgrade, invalid snapshots and v1/v2 isolation.

## Verified result and scope

**56/56 Linux Dart tests green.** The A4.1 and A4.2 test-only implementation remains unchanged. No schema conversion into the earlier A4.2 SQLite staged-restorer has been made; the new v2 archive is *not* accepted by that restorer.

The snapshot schema is deliberately bounded (**100 journals, 1,000 entries, 4,000 old revisions, 25 attachments, 2 MiB per attachment, 6 MiB whole plaintext payload**). These are test-prototype caps, **not product limits**. A real years-long archive must use authenticated streaming/chunked processing with bounded RAM. Memory wiping is best-effort and neither this design nor its dependencies have received independent security review.

## Required A4.3 follow-up (not completed)

1. **A4.3.3 consistent live-vault exporter:** create the final encrypted product schema, transactionally freeze a database snapshot (including ALL journals, revisions, Trash, attachment references and hashes), and guarantee writing while exporting cannot produce mismatched records. Refuse partial/incomplete backup; never expose plaintext temporary files.
2. **A4.3.4 crash-safe v2 restore:** authenticate v2, securely generate and protect the new device's database key, perform journal/revision/media foreign-key inserts in a single consistent encrypted store, independently reopen and compare, then publish with race-safe no-clobber and durable fsync. Never mutate an existing vault on failed restore. Implement explicit migrations.
3. **A4.3.5 clean Android-device proof:** simulate complete loss of original Android Keystore alias, transfer only external v2 archive + independently retained recovery key, then restore full fictional archive into a freshly installed Android app and verify journal/revision/Trash/media metadata and bytes. Add corruption, disk-full, power-loss/reinstall and physical-device tests.
4. Define understandable recovery-key custody, loss warnings and optional future passphrase/KDF UX. Independently review security and large-file availability before accepting private data.

**Do not treat this milestone as finished backup, production encryption, or a releasable journal APK.**

## Separate unresolved task

A3.3 Flutter editor emulator integration remains unresolved after Android emulator/package-service boot failures. A3.4 isolated Android force-stop/relaunch already passed; the two do not substitute for each other.
