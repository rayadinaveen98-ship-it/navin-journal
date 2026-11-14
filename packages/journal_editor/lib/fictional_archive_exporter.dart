/// APK 02 fictional-only portable encrypted archive handoff.
///
/// The archive itself may be placed in a user-selected Android Documents
/// provider, but that ALONE is not a usable backup. The independent recovery
/// key is returned only after a native write + readback check; it must be
/// recorded OFF this device, not stored in preferences or copied into logs.
/// This diagnostic does not enable real diary input or clean-device restore.
library;

import 'dart:typed_data';

import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_editor_isolate.dart';

class FictionalExportUnavailable implements Exception {
  const FictionalExportUnavailable();
  @override
  String toString() => 'FictionalExportUnavailable';
}

class FictionalArchiveExportReceipt {
  /// Ephemeral 43-character independent recovery key to transcribe offline.
  /// The native window must set FLAG_SECURE *before* showing this value.
  final String manualRecoveryKey;
  final int encryptedArchiveBytes;
  /// A provider readback checked bytes, not off-device recovery.
  final bool providerReadbackVerified;

  const FictionalArchiveExportReceipt({
    required this.manualRecoveryKey,
    required this.encryptedArchiveBytes,
    required this.providerReadbackVerified,
  });

  bool get cleanDeviceRestoreVerified => false;
  bool get keyCustodyVerified => false;
}

class FictionalArchiveExporter {
  const FictionalArchiveExporter._();

  /// [writeEncryptedArchive] owns a UI-mediated Android SAF document-create
  /// transaction and independently verifies bytes via provider readback.
  ///
  /// Returns null after user cancellation, with NO key disclosed. A failure
  /// after creating a document may leave a partial/unusable file at the
  /// selected location: the app must warn and MUST NOT auto-delete it.
  static Future<FictionalArchiveExportReceipt?> export({
    required JournalEditorWorker source,
    required Future<bool> Function(Uint8List encryptedArchive)
        writeEncryptedArchive,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product')) {
      throw const FictionalExportUnavailable();
    }
    final recoveryKey = RecoveryKey.random();
    Uint8List? encrypted;
    try {
      encrypted = await source.exportRecoveryArchive(recoveryKey);
      if (encrypted.isEmpty ||
          encrypted.length > ProductSnapshotCodec.maxPayloadBytes * 2) {
        throw const FictionalExportUnavailable();
      }
      // Even a just-created archive must be authenticated and schema
      // validated before any provider is asked to write it.
      await ProductEncryptedArchiveCodec().verify(
        recoveryKey: recoveryKey,
        archive: encrypted,
      );
      final savedAndReadBack = await writeEncryptedArchive(encrypted);
      if (!savedAndReadBack) return null;
      return FictionalArchiveExportReceipt(
        manualRecoveryKey: recoveryKey.exportForOfflineStorage(),
        encryptedArchiveBytes: encrypted.length,
        providerReadbackVerified: true,
      );
    } catch (_) {
      // No key, paths, archive bytes or content are included in errors.
      throw const FictionalExportUnavailable();
    } finally {
      encrypted?.fillRange(0, encrypted.length, 0);
      recoveryKey.destroy();
    }
  }
}
