/// APK 02 encrypted document import. FICTIONAL DIAGNOSTICS ONLY.
///
/// This reconstructs a v2 encrypted archive with a manually re-entered
/// independent key into a brand-new, disposable vault. The existing journal
/// is NEVER replaced, merged or opened for writing, and no recovered pages
/// are delivered to the Flutter interface. Clean-device/production recovery
/// remains unapproved until secure destination-key custody is implemented.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_editor_isolate.dart';
import 'portable_recovery_worker.dart';

class FictionalArchiveImportRejected implements Exception {
  const FictionalArchiveImportRejected();
  @override
  String toString() => 'FictionalArchiveImportRejected';
}

/// No plaintext, paths, key material, URI or journal names leave the importer.
class FictionalArchiveImportReport {
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;
  const FictionalArchiveImportReport({
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
  });
  bool get activeVaultReplaced => false;
  bool get independentlyRecoverableBackupVerified => false;
  bool get importedVaultRetained => false;
}

class FictionalArchiveImporter {
  const FictionalArchiveImporter._();

  /// The native ACTION_OPEN_DOCUMENT picker must read <= 32MiB into memory.
  /// [encryptedArchive] is OWNED by this method and is zeroed on return.
  ///
  /// An isolated random destination directory is created inside an EXISTING
  /// trusted private root. The restorer refuses replacement, validates the
  /// complete authenticated archive BEFORE staging, and opens a newly keyed
  /// SQLite vault. We independently reopen/verify it, then remove ONLY our
  /// owned disposable directory. No active vault, existing staging candidate
  /// or document-provider file is ever modified.
  ///
  /// A wrong, missing or malformed manually typed key fails closed without
  /// yielding content, counts or a persisted new journal.
  static Future<FictionalArchiveImportReport> inspect({
    required Uint8List encryptedArchive,
    required String manuallyEnteredRecoveryKey,
    required Directory trustedPrivateRoot,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product')) {
      encryptedArchive.fillRange(0, encryptedArchive.length, 0);
      throw const FictionalArchiveImportRejected();
    }
    RecoveryKey? recoveryKey;
    TestVaultKey? freshDatabaseKey;
    Directory? ownedRoot;
    JournalEditorWorker? reopened;
    try {
      if (encryptedArchive.isEmpty ||
          encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2 ||
          !await trustedPrivateRoot.exists()) {
        throw const FictionalArchiveImportRejected();
      }
      recoveryKey = RecoveryKey.parse(manuallyEnteredRecoveryKey);
      freshDatabaseKey = TestVaultKey.random();

      // No cleanup of unknown candidates. The parent itself is never erased.
      ownedRoot = await trustedPrivateRoot.createTemp(
        '.nj-fictional-import-review-',
      );
      final separateVault = Directory(
          '${ownedRoot.path}${Platform.pathSeparator}restored-vault');
      final restored = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: encryptedArchive,
        recoveryKey: recoveryKey,
        destinationKey: freshDatabaseKey,
        destination: separateVault,
      );

      // Independent off-UI encrypted worker reopen, plus referential checks.
      reopened = await JournalEditorWorker.open(
        '${separateVault.path}${Platform.pathSeparator}journal.sqlite3',
        key: freshDatabaseKey,
      );
      if (!await reopened.integrityCheck()) {
        throw const FictionalArchiveImportRejected();
      }
      final journals = await reopened.listJournals(includeTrash: true);
      final entries = await reopened.listEntries(includeTrash: true);
      final ids = journals.map((j) => j['id']).toSet();
      if (journals.length != restored.journals ||
          entries.length != restored.entries ||
          entries.any((e) => !ids.contains(e['journalId']))) {
        throw const FictionalArchiveImportRejected();
      }
      var versions = 0;
      for (final entry in entries) {
        versions += await reopened.historyCount(entry['id'] as String);
      }
      if (versions != restored.revisions) {
        throw const FictionalArchiveImportRejected();
      }
      return FictionalArchiveImportReport(
        journals: restored.journals,
        entries: restored.entries,
        revisions: restored.revisions,
        attachments: restored.attachments,
      );
    } catch (_) {
      // Never disclose whether key syntax, archive integrity, or storage
      // failed; no plaintext, file path or sensitive key enters error text.
      throw const FictionalArchiveImportRejected();
    } finally {
      try {
        await reopened?.close();
      } finally {
        try {
          // Only this call's unique directory, never the private root,
          // existing journals or orphaned restore stages.
          if (ownedRoot != null && await ownedRoot.exists()) {
            await ownedRoot.delete(recursive: true);
          }
        } finally {
          recoveryKey?.destroy();
          freshDatabaseKey?.destroy();
          encryptedArchive.fillRange(0, encryptedArchive.length, 0);
        }
      }
    }
  }
}
