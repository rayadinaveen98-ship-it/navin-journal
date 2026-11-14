/// Stage 5A: retained, isolated, Keystore-enveloped fictional recovery candidate.
///
/// Important: this never activates, overwrites, replaces or merges an active
/// journal. It retains a separately named app-private encrypted candidate
/// so a second process can independently reopen it using the NEW device's
/// wrapping key. A candidate with a missing/corrupt envelope fails closed.
///
/// A fresh archive and separately supplied key remain necessary for retry:
/// failed/incomplete candidates are deliberately NOT automatically deleted.
/// This is an engineering diagnostic, not private-data backup or release UX.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_editor_isolate.dart';
import 'portable_recovery_worker.dart';

class FictionalRetainedRecoveryRejected implements Exception {
  const FictionalRetainedRecoveryRejected();
  @override
  String toString() => 'FictionalRetainedRecoveryRejected';
}

/// Counts only; never expose a vault path, database key, envelope alias,
/// decrypted content or the externally supplied recovery key in a UI.
class FictionalRetainedRecoveryReport {
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;

  const FictionalRetainedRecoveryReport({
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
  });

  bool get activeJournalReplaced => false;
  bool get activatedForPersonalWriting => false;
  bool get physicalDeviceRecoveryVerified => false;
}

class FictionalRetainedRecoveryCandidate {
  const FictionalRetainedRecoveryCandidate._();

  /// Dedicated, deliberately fixed name. Repeated imports cannot create
  /// another untracked collection or overwrite a previous recovery candidate.
  static const candidateDirectoryName = 'nj-fictional-retained-candidate-v1';
  static const _vaultDirectoryName = 'vault';
  static const _envelopeName = 'envelope.json';
  static const _databaseName = 'journal.sqlite3';

  static Directory _root(Directory privateRoot) =>
      Directory(privateRoot.path + Platform.pathSeparator +
          candidateDirectoryName);

  static File _envelope(Directory root) =>
      File(root.path + Platform.pathSeparator + _envelopeName);

  static Directory _vault(Directory root) =>
      Directory(root.path + Platform.pathSeparator + _vaultDirectoryName);

  static File _database(Directory root) =>
      File(_vault(root).path + Platform.pathSeparator + _databaseName);

  static Future<FileSystemEntityType> _type(String path) =>
      FileSystemEntity.type(path, followLinks: false);

  static Future<void> _requireTrustedRoot(Directory privateRoot) async {
    if (privateRoot.path.trim().isEmpty ||
        await _type(privateRoot.absolute.path) !=
            FileSystemEntityType.directory) {
      throw const FictionalRetainedRecoveryRejected();
    }
  }

  /// Deliberately leaves only freshly-created *our-own* candidate intact on
  /// all failures. If an OS kill occurs between publication and envelope
  /// verification, do NOT silently reset the new-device key or erase data.
  ///
  /// A real Android call must supply FlutterAndroidKeyProtector; tests supply
  /// an explicit *insecure* deterministic fake. Never fall back to software.
  static Future<FictionalRetainedRecoveryReport> prepare({
    required Uint8List encryptedArchive,
    required String manuallyEnteredRecoveryKey,
    required Directory trustedPrivateRoot,
    required DeviceKeyProtector deviceProtector,
    void Function(String checkpoint)? injectFailure,
  }) async {
    RecoveryKey? recovery;
    Uint8List? databaseKeyBytes;
    TestVaultKey? databaseKey;
    JournalEditorWorker? opened;
    try {
      if (const bool.fromEnvironment('dart.vm.product')) {
        throw const FictionalRetainedRecoveryRejected();
      }
      await _requireTrustedRoot(trustedPrivateRoot);
      final candidate = _root(trustedPrivateRoot);
      // Refuse existing directories, files AND symlinks. Never recursively
      // delete, reuse, merge, rekey or 'fix up' an unknown candidate.
      if (await _type(candidate.path) != FileSystemEntityType.notFound ||
          encryptedArchive.isEmpty ||
          encryptedArchive.length > 32 * 1024 * 1024 ||
          encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2) {
        throw const FictionalRetainedRecoveryRejected();
      }
      recovery = RecoveryKey.parse(manuallyEnteredRecoveryKey);

      // Authenticate the complete payload BEFORE creating ANY candidate
      // directory or Android KeyStore alias, so wrong keys/tampered archives
      // leave the private filesystem unchanged.
      final verified = await ProductEncryptedArchiveCodec().verify(
        archive: encryptedArchive, recoveryKey: recovery);
      injectFailure?.call('after_authentication_before_candidate');

      // Creating a reserved fixed directory makes a crash visible to safe
      // staging review and blocks subsequent automatic imports.
      await candidate.create(recursive: false);
      injectFailure?.call('after_candidate_reserved');

      final envelope = KeyEnvelopeCoordinator(
        envelopeFile: _envelope(candidate),
        protector: deviceProtector,
      );
      // The vault path must remain ABSENT while the new Android Keystore DEK
      // is generated and wrapped. The envelope is stored as a sibling.
      databaseKeyBytes = await envelope.initialize(
        databasePath: _database(candidate).path,
      );
      databaseKey = TestVaultKey.fromBytes(databaseKeyBytes);
      injectFailure?.call('after_new_device_envelope');

      // This is an already verified archive; restore still independently
      // authenticates it and publishes only into an ABSENT "vault" path.
      final restored = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: encryptedArchive,
        recoveryKey: recovery,
        destinationKey: databaseKey,
        destination: _vault(candidate),
      );
      injectFailure?.call('after_encrypted_vault_published');

      // Verify the *actual* device-protected envelope, not merely the in-
      // memory destination key passed to the restore operation.
      final reopenedBytes = await envelope.unlock(
        databasePath: _database(candidate).path,
      );
      try {
        final reopenedKey = TestVaultKey.fromBytes(reopenedBytes);
        try {
          opened = await JournalEditorWorker.open(
            _database(candidate).path, key: reopenedKey);
        } finally {
          reopenedKey.destroy();
        }
      } finally {
        reopenedBytes.fillRange(0, reopenedBytes.length, 0);
      }
      if (!await opened.integrityCheck()) {
        throw const FictionalRetainedRecoveryRejected();
      }
      final journals = await opened.listJournals(includeTrash: true);
      final entries = await opened.listEntries(includeTrash: true);
      final ids = journals.map((j) => j['id']).toSet();
      var priorVersions = 0;
      for (final page in entries) {
        if (!ids.contains(page['journalId'])) {
          throw const FictionalRetainedRecoveryRejected();
        }
        priorVersions += await opened.historyCount(page['id'] as String);
      }
      if (journals.length != restored.journals ||
          entries.length != restored.entries ||
          priorVersions != restored.revisions ||
          restored.journals != (verified['journals'] as List).length ||
          restored.entries != (verified['entries'] as List).length ||
          restored.revisions != (verified['revisions'] as List).length ||
          restored.attachments != (verified['attachments'] as List).length ||
          !await NativeRestorePublisher.isReady(_vault(candidate))) {
        throw const FictionalRetainedRecoveryRejected();
      }
      injectFailure?.call('after_independent_envelope_reopen');
      return FictionalRetainedRecoveryReport(
        journals: restored.journals,
        entries: restored.entries,
        revisions: restored.revisions,
        attachments: restored.attachments,
      );
    } catch (_) {
      throw const FictionalRetainedRecoveryRejected();
    } finally {
      try {
        await opened?.close();
      } finally {
        databaseKey?.destroy();
        databaseKeyBytes?.fillRange(0, databaseKeyBytes.length, 0);
        recovery?.destroy();
        encryptedArchive.fillRange(0, encryptedArchive.length, 0);
      }
    }
  }

  /// A separate process invocation must succeed using *only* the persisted
  /// envelope and the device's existing Keystore alias, not the archive,
  /// original device data key or manually recorded recovery key.
  static Future<FictionalRetainedRecoveryReport> reopen({
    required Directory trustedPrivateRoot,
    required DeviceKeyProtector deviceProtector,
  }) async {
    Uint8List? unwrapped;
    JournalEditorWorker? opened;
    TestVaultKey? key;
    try {
      if (const bool.fromEnvironment('dart.vm.product')) {
        throw const FictionalRetainedRecoveryRejected();
      }
      await _requireTrustedRoot(trustedPrivateRoot);
      final candidate = _root(trustedPrivateRoot);
      if (await _type(candidate.path) != FileSystemEntityType.directory ||
          await _type(_envelope(candidate).path) != FileSystemEntityType.file ||
          await _type(_vault(candidate).path) != FileSystemEntityType.directory ||
          await _type(_database(candidate).path) != FileSystemEntityType.file ||
          !await NativeRestorePublisher.isReady(_vault(candidate))) {
        throw const FictionalRetainedRecoveryRejected();
      }
      final envelope = KeyEnvelopeCoordinator(
        envelopeFile: _envelope(candidate), protector: deviceProtector);
      unwrapped = await envelope.unlock(
        databasePath: _database(candidate).path);
      key = TestVaultKey.fromBytes(unwrapped);
      opened = await JournalEditorWorker.open(
        _database(candidate).path, key: key);
      if (!await opened.integrityCheck()) {
        throw const FictionalRetainedRecoveryRejected();
      }
      final journals = await opened.listJournals(includeTrash: true);
      final entries = await opened.listEntries(includeTrash: true);
      final owners = journals.map((j) => j['id']).toSet();
      var revisions = 0;
      for (final item in entries) {
        if (!owners.contains(item['journalId'])) {
          throw const FictionalRetainedRecoveryRejected();
        }
        revisions += await opened.historyCount(item['id'] as String);
      }
      // Count retained media from an independently authenticated *new*
      // encrypted full-schema export, never from a guessed page count.
      final reviewKey = RecoveryKey.random();
      Uint8List? reviewArchive;
      int attachments;
      try {
        reviewArchive = await opened.exportRecoveryArchive(reviewKey);
        final snapshot = await ProductEncryptedArchiveCodec().verify(
          archive: reviewArchive, recoveryKey: reviewKey);
        attachments = (snapshot['attachments'] as List).length;
        if ((snapshot['journals'] as List).length != journals.length ||
            (snapshot['entries'] as List).length != entries.length ||
            (snapshot['revisions'] as List).length != revisions) {
          throw const FictionalRetainedRecoveryRejected();
        }
      } finally {
        reviewArchive?.fillRange(0, reviewArchive.length, 0);
        reviewKey.destroy();
      }
      return FictionalRetainedRecoveryReport(
        journals: journals.length,
        entries: entries.length,
        revisions: revisions,
        attachments: attachments,
      );
    } catch (_) {
      throw const FictionalRetainedRecoveryRejected();
    } finally {
      await opened?.close();
      key?.destroy();
      unwrapped?.fillRange(0, unwrapped.length, 0);
    }
  }
}
