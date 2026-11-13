# Release acceptance criteria — initial test matrix

**These tests are specifications, not tests run.**

| ID | Scenario | Expected behavior | Priority |
|----|----------|-------------------|----------|
| R-001 | Write 1,000+ words with network off | Entry is saved, readable and editable locally | P0 |
| R-002 | Force-stop app while typing | Last committed content and draft recovery remain intact | P0 |
| R-003 | Close empty untouched entry | No blank permanent entry | P0 |
| R-004 | Type Telugu, English, mixed punctuation and emoji | Exact Unicode preserved through storage/search/export/restore | P0 |
| R-005 | Rename and move entry among journals | Stable ID and content preserved, dates unchanged | P0 |
| R-006 | Delete entry, then restore | Original text/media and metadata recovered | P0 |
| R-007 | Delete journal with entries | Explicit confirmation, recoverability and scope communicated | P0 |
| R-008 | Import malformed attachment or remove permission | Clear error; prior content unaffected | P0 |
| R-009 | Exhaust free storage during write | No corruption of previously committed content; visible warning | P0 |
| R-010 | Export/restore complete fixture | Match entry count, journal IDs, text, attachments and hashes | P0 |
| R-011 | Restore tampered archive | Reject safely without mutating destination vault | P0 |
| R-012 | Unlock after app restarts | Secure local lock behaves consistently | P0 |
| R-013 | Search entries across date ranges/tags | Correct results and no plaintext leak when locked | P0 |
| R-014 | 10,000-entry representative test archive | Scrolling, search and pagination meet benchmark agreed after baseline | P0 |
| R-015 | Screen reader / large fonts / reduced motion | All core flows operable; no clipping or blocked actions | P0 |
| R-016 | Create entry event date different from write date | Both dates displayed accurately | P0 |
| R-017 | Start an edit on two devices while offline | Concurrent content is not silently overwritten | P1 sync |
| R-018 | Reinstall app and restore backup on clean device | Full archive and attachments verified; no unexpected sign-in requirement for offline archive | P0 |
| R-019 | Resume interrupted sync after connection returns | Eventually consistent without missing or duplicated entries | P1 sync |
| R-020 | Export without a subscription | User can retrieve readable original writing and media | Product policy |

## Gates

**UX gate:** First entry / find-entry / restore tasks tested with prospective users; friction documented and resolved.  
**Engineering gate:** Crash, large-archive, full-storage and migration tests pass on real target devices.  
**Security gate:** Threat review, key recovery documentation, static/dependency scanning and appropriate independent assessment complete.  
**Release gate:** Signed APK/build provenance, explicit versioning, accessible privacy policy, supported device list and reproducible restore evidence.

Benchmark values (latency, thermal behavior, backup time, cold-start targets) require instrumented baselines before they can be set responsibly.
