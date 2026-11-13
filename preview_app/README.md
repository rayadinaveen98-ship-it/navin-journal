# Navin Journal — APK 01, native visual-preview shell

**Status:** Stage 5 entry / visual-review milestone. This is NOT the functional journal.

The approved Stage 3 Still Pages + Memory Atelier direction and Midnight Archive dark theme are implemented as a standalone, phone/tablet responsive Flutter UI source. A custom Flutter-painted Folded Page mark reproduces the selected Stage 3 SVG. Android launcher resources use the staged VectorDrawable/adaptive icon artwork.

## Screens connected

- Welcome and one-time-looking sample journal setup (memory only; not persistent)
- Today and fictional entry cards
- Journals library and journal detail
- Sample Reader and demonstration Writing Studio
- Memories Timeline, November 2026 Calendar and illustrated Gallery
- Discover sample search
- Settings appearance switch, Archive/Trash and Backup concept screens

A small banner on every screen clearly states that this is a visual preview with fictional data and **NO SAVING**. The editor warns against private writing and requires an explicit discard confirmation when exiting a non-empty sample draft. All UI state resets after app restart. **There is no encrypted storage, production autosave, local recovery, real backup/restore, secure lock, account, cloud sync, database, or data collection.**

## CI and APK

GitHub Actions workflow: [Navin Journal Visual Preview APK](../.github/workflows/journal-preview-apk.yml).

On preview source changes and manually through workflow_dispatch, CI:

1. Generates a throwaway Flutter Android project with stable Flutter.
2. Copies the tracked preview Dart files and six test widgets.
3. Installs approved Folded Page launcher VectorDrawable/adaptive icon XML.
4. Runs Flutter analysis, phone/tablet navigation and safety-copy widget tests.
5. Builds an **Android debug APK** and uploads an artifact named
   **navin-journal-apk-01-VISUAL-DEMO-NO-SAVING** with 14-day retention.

Visit the workflow's latest successful run, scroll to **Artifacts**, download the ZIP and extract app-debug.apk. The ZIP is not directly installable; the extracted APK is. Debug builds are signed with the ephemeral GitHub Actions debug key and are **not suitable for upgrades to a real-data beta or Play Store release**. The user may have to uninstall the preview before the future functional beta. Do not type actual diaries in the test build.

## Runtime and layout review

- 360/390/430px phones: four-destination bottom navigation; Writer hides it.
- 600–899px tablets: compact rail; 900+ expanded rail.
- Responsive book, calendar, memory and entry layouts with centered long-form reading.
- Light/dark semantic tokens from docs/DESIGN_SYSTEM_V1.md.
- Original procedural landscape illustrations (not downloaded stock media).
- No network/account/media permission requested by Dart source.
- Real device checks remain OPEN: Telugu IME, TalkBack, system font 200% reflow, physical Android 15/16, launcher mask and power/reboot behavior.

## Reproduce locally

From a machine with Flutter and Android SDK installed:

1. Run flutter create --org com.navinjournal --project-name navin_journal_preview --platforms=android generated.
2. Copy preview_app/lib/*.dart to generated/lib/ and preview_app/test/*.dart to generated/test/ (delete generated default test).
3. Copy prototype/brand/android/drawable/*.xml to generated/android/app/src/main/res/drawable/.
4. Copy prototype/brand/android/mipmap-anydpi-v26/navin_journal_ic_launcher.xml to generated/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml.
5. Run flutter pub get, flutter analyze, flutter test and flutter build apk --debug in generated/.

The CI workflow is the canonical reproducible recipe and includes the manifest label.

## Not included in APK 01

Functional editing and durable save, journals CRUD, real photos/audio, backups and restores, local encryption/Keystore, revisions, Trash, secure migration, Google login, background work, optional AI and all Stage 6 release verification. Those remain in the upcoming integration stages. Do not interpret widget tests as production data-loss or privacy guarantees.
