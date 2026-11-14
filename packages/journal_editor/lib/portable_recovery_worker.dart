/// APK02 independent portable recovery worker — FICTIONAL FIXTURES ONLY.
///
/// Authenticated v2 archives are restored to an ABSENT directory using a
/// freshly generated destination database key. Staging, SQLite3MC transactions,
/// and exact close/reopen checks happen on an off-UI isolate. This is a test
/// bridge, NOT an approved production backup/restore or Android key UI.
///
/// The caller holds its archive and independent recovery key separately.
/// It must still securely envelope-wrap the new destination key and implement
/// native no-replace/fsync before any real user data can be restored.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

class PortableRecoveryWorker {
  const PortableRecoveryWorker._();

  /// Non-destructive, fictional-only assessment of one quarantined stage.
  /// All decryption and SQLite operations are performed on an encrypted COPY
  /// in a background isolate. The caller receives only status and row counts;
  /// never plaintext journal content or the raw recovery/database keys.
  static Future<RestoreAssessment> assessQuarantinedStage({
    required Directory privateParent,
    required String candidateBasename,
    required Uint8List encryptedArchive,
    required RecoveryKey recoveryKey,
    required TestVaultKey stagedDatabaseKey,
  }) async {
    if (encryptedArchive.isEmpty ||
        encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2) {
      throw const ProductRestoreRejected();
    }
    final archiveTransfer = TransferableTypedData.fromList([encryptedArchive]);
    final recoveryBytes = recoveryKey.snapshot();
    final databaseHex = stagedDatabaseKey.hex;
    final databaseBytes = Uint8List.fromList([
      for (var i = 0; i < databaseHex.length; i += 2)
        int.parse(databaseHex.substring(i, i + 2), radix: 16),
    ]);
    final recoveryTransfer = TransferableTypedData.fromList([recoveryBytes]);
    final databaseTransfer = TransferableTypedData.fromList([databaseBytes]);
    final parentPath = privateParent.path;
    try {
      return await Isolate.run(() async {
        final archive = archiveTransfer.materialize().asUint8List();
        final rawRecovery = recoveryTransfer.materialize().asUint8List();
        final rawDatabase = databaseTransfer.materialize().asUint8List();
        RecoveryKey? isolatedRecovery;
        TestVaultKey? isolatedDatabase;
        try {
          isolatedRecovery = RecoveryKey.parse(
            base64Url.encode(rawRecovery).replaceAll('=', ''),
          );
          isolatedDatabase = TestVaultKey.fromBytes(rawDatabase);
          return await RestoreStagingAssessment.assess(
            privateParent: Directory(parentPath),
            candidateBasename: candidateBasename,
            encryptedArchive: archive,
            recoveryKey: isolatedRecovery,
            stagedDatabaseKey: isolatedDatabase,
          );
        } finally {
          isolatedRecovery?.destroy();
          isolatedDatabase?.destroy();
          archive.fillRange(0, archive.length, 0);
          rawRecovery.fillRange(0, rawRecovery.length, 0);
          rawDatabase.fillRange(0, rawDatabase.length, 0);
        }
      });
    } finally {
      recoveryBytes.fillRange(0, recoveryBytes.length, 0);
      databaseBytes.fillRange(0, databaseBytes.length, 0);
    }
  }


  /// Refuses to replace any existing destination. The source archive is
  /// authenticated before a staging directory is created by the restorer.
  /// The original Android device key is NOT required.
  static Future<ProductRestoreReceipt> restoreToNewVault({
    required Uint8List encryptedArchive,
    required RecoveryKey recoveryKey,
    required TestVaultKey destinationKey,
    required Directory destination,
    /// TEST ONLY: inject a simulated storage failure at a verified checkpoint.
    /// Rejected in release builds. Never use for private data.
    String? faultCheckpointForDiagnostics,
  }) async {
    if (faultCheckpointForDiagnostics != null) {
      if (const bool.fromEnvironment('dart.vm.product') ||
          !const {
            'after_ready_marker_write',
            'before_staged_file_fsync',
            'before_parent_post_rename_fsync',
          }.contains(faultCheckpointForDiagnostics)) {
        throw const ProductRestoreRejected();
      }
    }
    if (encryptedArchive.isEmpty ||
        encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2 ||
        destination.path.trim().isEmpty) {
      throw const ProductRestoreRejected();
    }
    final destinationPath = destination.path;
    final recoveryBytes = recoveryKey.snapshot();
    final dbHex = destinationKey.hex;
    final dbBytes = Uint8List.fromList(
      List<int>.generate(32, (i) =>
        int.parse(dbHex.substring(i * 2, i * 2 + 2), radix: 16)),
    );
    try {
      final archiveTransfer = TransferableTypedData.fromList([encryptedArchive]);
      final recoveryTransfer = TransferableTypedData.fromList([recoveryBytes]);
      final dbTransfer = TransferableTypedData.fromList([dbBytes]);
      try {
        return await Isolate.run(() async {
        final archive = archiveTransfer.materialize().asUint8List();
        final rawRecovery = recoveryTransfer.materialize().asUint8List();
        final rawDatabase = dbTransfer.materialize().asUint8List();
        RecoveryKey? isolatedRecovery;
        TestVaultKey? isolatedDb;
        try {
          // No passphrase, diary bytes or key text should be logged.
          isolatedRecovery = RecoveryKey.parse(
            base64Url.encode(rawRecovery).replaceAll('=', ''),
          );
          isolatedDb = TestVaultKey.fromBytes(rawDatabase);
          return await StagedProductRestorer(
            injectFailure: faultCheckpointForDiagnostics == null ? null : (point) {
              if (point == faultCheckpointForDiagnostics) {
                throw FileSystemException(
                  'Fictional ENOSPC injected by diagnostic harness',
                  destinationPath,
                  const OSError('No space left on device', 28),
                );
              }
            },
          ).restoreNew(
            encryptedArchive: archive,
            recoveryKey: isolatedRecovery,
            destinationKey: isolatedDb,
            destination: Directory(destinationPath),
          );
        } finally {
          isolatedRecovery?.destroy();
          isolatedDb?.destroy();
          rawRecovery.fillRange(0, rawRecovery.length, 0);
          rawDatabase.fillRange(0, rawDatabase.length, 0);
          archive.fillRange(0, archive.length, 0);
        }
        });
      } on ArchiveRejected {
        // No user data/key details cross the UI boundary on bad credentials,
        // tampered archives or malformed recovery input.
        throw const ProductRestoreRejected();
      }
    } finally {
      recoveryBytes.fillRange(0, recoveryBytes.length, 0);
      dbBytes.fillRange(0, dbBytes.length, 0);
    }
  }

}
