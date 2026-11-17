/// Stage 5D.1-E5: external V3 encrypted recovery proof, FICTIONAL ONLY.
/// Not a consumer backup, held-key guarantee or restored usable journal.
/// The legacy V2 export, import and retained-candidate flows remain untouched.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_archive_v3.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'fictional_archive_exporter.dart';
import 'journal_editor_isolate.dart';
import 'portable_recovery_worker.dart';

class FictionalV3TransferRejected implements Exception {
  const FictionalV3TransferRejected();
  @override
  String toString() => 'FictionalV3TransferRejected';
}

/// Counts only. The restored vault is deleted after independent verification.
class FictionalV3ImportReport {
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;
  final int conflictReceipts;

  const FictionalV3ImportReport({
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
    required this.conflictReceipts,
  });

  bool get activeVaultReplaced => false;
  bool get retainedForFutureUse => false;
  bool get privateDataReady => false;
  bool get newDeviceKeyCustodyVerified => false;
}

class FictionalV3ExternalTransfer {
  const FictionalV3ExternalTransfer._();

  /// Native SAF writes only encrypted bytes and must verify provider readback.
  /// Only disclose the independent key after provider verification succeeds.
  static Future<FictionalArchiveExportReceipt?> export({
    required JournalEditorWorker source,
    required Future<bool> Function(Uint8List encryptedArchive)
        writeEncryptedArchive,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product')) {
      throw const FictionalV3TransferRejected();
    }
    final recovery = RecoveryKey.random();
    Uint8List? encrypted;
    try {
      encrypted = await source.exportRecoveryArchiveV3(recovery);
      if (encrypted.isEmpty ||
          encrypted.length > ProductSnapshotCodec.maxPayloadBytes * 2) {
        throw const FictionalV3TransferRejected();
      }
      final verified = await ProductArchiveV3Codec().verify(
        recoveryKey: recovery,
        archive: encrypted,
      );
      if (verified.archiveFormat != ProductArchiveV3Codec.format ||
          !verified.hasAuthenticatedConflictProvenance) {
        throw const FictionalV3TransferRejected();
      }
      if (!await writeEncryptedArchive(encrypted)) return null;
      return FictionalArchiveExportReceipt(
        manualRecoveryKey: recovery.exportForOfflineStorage(),
        encryptedArchiveBytes: encrypted.length,
        providerReadbackVerified: true,
      );
    } catch (_) {
      throw const FictionalV3TransferRejected();
    } finally {
      encrypted?.fillRange(0, encrypted.length, 0);
      recovery.destroy();
    }
  }

  /// Authentic V3 recovery with conflict provenance into a newly generated
  /// separately keyed, disposable directory. Reject V2 even when valid.
  /// Neither a provider file nor any existing active vault is modified.
  ///
  /// The caller transfers ownership of encryptedArchive. All owned buffers,
  /// keys and only the temporary inspection directory are cleaned up.
  static Future<FictionalV3ImportReport> inspect({
    required Uint8List encryptedArchive,
    required String manuallyEnteredRecoveryKey,
    required Directory trustedPrivateRoot,
  }) async {
    RecoveryKey? recovery;
    TestVaultKey? destinationKey;
    Directory? ownedRoot;
    JournalEditorWorker? reopened;
    try {
      if (const bool.fromEnvironment('dart.vm.product') ||
          encryptedArchive.isEmpty ||
          encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2 ||
          trustedPrivateRoot.path.trim().isEmpty ||
          !await trustedPrivateRoot.exists()) {
        throw const FictionalV3TransferRejected();
      }
      recovery = RecoveryKey.parse(manuallyEnteredRecoveryKey);
      // Validate before reserving any disk state. The staged restorer
      // independently validates and verifies the same encrypted container.
      final verified = await ProductArchiveV3Codec().verify(
        recoveryKey: recovery,
        archive: encryptedArchive,
      );
      if (verified.archiveFormat != ProductArchiveV3Codec.format ||
          !verified.hasAuthenticatedConflictProvenance) {
        throw const FictionalV3TransferRejected();
      }

      destinationKey = TestVaultKey.random();
      ownedRoot = await trustedPrivateRoot.createTemp(
          '.nj-fictional-v3-import-review-');
      final destination = Directory(
          '${ownedRoot.path}${Platform.pathSeparator}new-encrypted-vault');
      final result = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: encryptedArchive,
        recoveryKey: recovery,
        destinationKey: destinationKey,
        destination: destination,
        v3Only: true,
      );
      reopened = await JournalEditorWorker.open(
        '${destination.path}${Platform.pathSeparator}journal.sqlite3',
        key: destinationKey,
      );
      if (!await reopened.integrityCheck()) {
        throw const FictionalV3TransferRejected();
      }
      final notebooks = await reopened.listJournals(includeTrash: true);
      final pages = await reopened.listEntries(includeTrash: true);
      final notebookIds = notebooks.map((v) => v['id']).toSet();
      if (notebooks.length != result.journals ||
          pages.length != result.entries ||
          pages.any((v) => !notebookIds.contains(v['journalId']))) {
        throw const FictionalV3TransferRejected();
      }
      var revisionCount = 0;
      for (final page in pages) {
        revisionCount += await reopened.historyCount(page['id'] as String);
      }
      if (revisionCount != result.revisions) {
        throw const FictionalV3TransferRejected();
      }

      final expectedReceipts = verified.snapshot['conflictCopyReceipts'] as List;
      final sourceIds = expectedReceipts.map(
          (raw) => (raw as Map)['sourceEntryId'] as String).toSet();
      final restoredReceipts = <String, Map<String, Object?>>{};
      for (final source in sourceIds) {
        final rows = await reopened.fictionalConflictCopiesForSource(source);
        for (final row in rows) {
          final operation = row['operationId'] as String;
          if (restoredReceipts.containsKey(operation)) {
            throw const FictionalV3TransferRejected();
          }
          restoredReceipts[operation] = row;
        }
      }
      if (restoredReceipts.length != expectedReceipts.length) {
        throw const FictionalV3TransferRejected();
      }
      for (final raw in expectedReceipts) {
        final record = raw as Map;
        final restored = restoredReceipts[record['operationId']];
        if (restored == null ||
            restored['sourceEntryId'] != record['sourceEntryId'] ||
            restored['expectedOriginalVersion'] !=
                record['expectedOriginalVersion'] ||
            restored['competingOriginalVersion'] !=
                record['competingOriginalVersion'] ||
            restored['journalId'] != record['journalId'] ||
            restored['copyEntryId'] != record['copyEntryId']) {
          throw const FictionalV3TransferRejected();
        }
      }
      return FictionalV3ImportReport(
        journals: result.journals,
        entries: result.entries,
        revisions: result.revisions,
        attachments: result.attachments,
        conflictReceipts: expectedReceipts.length,
      );
    } catch (_) {
      // Never return recovery keys, filenames, page text or SQL details.
      throw const FictionalV3TransferRejected();
    } finally {
      try {
        await reopened?.close();
      } finally {
        try {
          if (ownedRoot != null && await ownedRoot.exists()) {
            await ownedRoot.delete(recursive: true);
          }
        } finally {
          recovery?.destroy();
          destinationKey?.destroy();
          encryptedArchive.fillRange(0, encryptedArchive.length, 0);
        }
      }
    }
  }
}
