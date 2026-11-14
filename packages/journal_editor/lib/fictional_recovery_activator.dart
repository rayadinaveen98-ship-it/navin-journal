/// Stage 5A fictional-only explicit activation of a complete recovery candidate.
///
/// The *entire* encrypted candidate (existing Android Keystore envelope AND
/// restored SQLite database) is atomically promoted into an ABSENT diagnostic
/// Library slot. No rekeying, copying plaintext, merge, replacement or erase.
///
/// A permanent exclusive reservation + approval marker record crash states.
/// An interrupted or ambiguous state is NEVER reset, retried or cleaned up.
/// Even a successful activation remains FICTIONAL and NOT a private diary beta.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'fictional_retained_recovery_candidate.dart';
import 'journal_editor_isolate.dart';

class FictionalActivationRejected implements Exception {
  const FictionalActivationRejected();
  @override
  String toString() => 'FictionalActivationRejected';
}

enum FictionalActivationState {
  /// No known candidate or activation state; not authority to create a vault.
  notPrepared,
  /// Complete candidate present but destination is absent.
  awaitingExplicitApproval,
  /// Approved encrypted active slot exists and independently reopens.
  activeFictionalVault,
  /// Unknown, occupied, incomplete or interrupted: never auto-repair.
  unsafeOrInterrupted,
}

class FictionalActivationReceipt {
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;
  const FictionalActivationReceipt({
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
  });

  bool get existingVaultReplaced => false;
  bool get privateWritingApproved => false;
  bool get deviceRecoveryCertified => false;
}

class FictionalRecoveryActivator {
  const FictionalRecoveryActivator._();

  /// This is the existing APK02 Library fixture destination, NOT a second
  /// arbitrary active directory. Existing normal APK02 installs occupy it.
  static const activeDirectoryName = 'nj_apk02_library_fixture';
  static const activationReservationName =
      'nj_apk02_library_fixture.activation-reservation';

  static Directory _active(Directory parent) =>
      Directory(parent.path + Platform.pathSeparator + activeDirectoryName);
  static Directory _candidate(Directory parent) => Directory(parent.path +
      Platform.pathSeparator +
      FictionalRetainedRecoveryCandidate.candidateDirectoryName);
  static File _reservation(Directory parent) =>
      File(parent.path + Platform.pathSeparator + activationReservationName);
  static File _candidateReservation(Directory parent) =>
      File(_candidate(parent).path + '.reservation');

  static Future<FileSystemEntityType> _kind(String path) =>
      FileSystemEntity.type(path, followLinks: false);

  static Future<void> _trust(Directory parent) async {
    if (parent.path.trim().isEmpty ||
        await _kind(parent.absolute.path) !=
            FileSystemEntityType.directory) {
      throw const FictionalActivationRejected();
    }
  }

  /// Pure read-only classification: never starts recovery or deletes an
  /// interrupted candidate. A committed active slot must carry its marker,
  /// activation reservation and the source-side exclusive reservation.
  static Future<FictionalActivationState> inspect({
    required Directory trustedPrivateRoot,
  }) async {
    try {
      if (const bool.fromEnvironment('dart.vm.product')) {
        throw const FictionalActivationRejected();
      }
      await _trust(trustedPrivateRoot);
      final active = await _kind(_active(trustedPrivateRoot).path);
      final candidate = await _kind(_candidate(trustedPrivateRoot).path);
      final lock = await _kind(_reservation(trustedPrivateRoot).path);
      final candidateLock =
          await _kind(_candidateReservation(trustedPrivateRoot).path);

      if (active == FileSystemEntityType.notFound &&
          lock == FileSystemEntityType.notFound &&
          candidate == FileSystemEntityType.notFound &&
          candidateLock == FileSystemEntityType.notFound) {
        return FictionalActivationState.notPrepared;
      }
      if (active == FileSystemEntityType.notFound &&
          lock == FileSystemEntityType.notFound &&
          candidate == FileSystemEntityType.directory &&
          candidateLock == FileSystemEntityType.file &&
          await NativeRestorePublisher.isReady(Directory(
              _candidate(trustedPrivateRoot).path + '/vault'))) {
        return FictionalActivationState.awaitingExplicitApproval;
      }
      if (active == FileSystemEntityType.directory &&
          candidate == FileSystemEntityType.notFound &&
          lock == FileSystemEntityType.file &&
          candidateLock == FileSystemEntityType.file &&
          await NativeRestorePublisher.isFictionalActivationReady(
              _active(trustedPrivateRoot))) {
        return FictionalActivationState.activeFictionalVault;
      }
      return FictionalActivationState.unsafeOrInterrupted;
    } catch (_) {
      return FictionalActivationState.unsafeOrInterrupted;
    }
  }

  /// The caller must deliver a real explicit confirmation (NOT consent
  /// inferred from a previous file-picker selection or candidate import).
  /// To avoid a TOCTOU overwrite, both the permanent exclusive activation
  /// reservation AND the kernel RENAME_NOREPLACE gate are mandatory.
  static Future<FictionalActivationReceipt> approveAndActivate({
    required Directory trustedPrivateRoot,
    required DeviceKeyProtector deviceProtector,
    required bool userExplicitlyApproved,
    void Function(String checkpoint)? injectFailure,
  }) async {
    try {
      if (!userExplicitlyApproved ||
          const bool.fromEnvironment('dart.vm.product')) {
        throw const FictionalActivationRejected();
      }
      await _trust(trustedPrivateRoot);
      if (await inspect(trustedPrivateRoot: trustedPrivateRoot) !=
          FictionalActivationState.awaitingExplicitApproval) {
        throw const FictionalActivationRejected();
      }
      // Strong Keystore unwrap and full encrypted count authentication
      // BEFORE allocating any activation reservation, never just file name.
      final verified = await FictionalRetainedRecoveryCandidate.reopen(
        trustedPrivateRoot: trustedPrivateRoot,
        deviceProtector: deviceProtector,
      );
      if (verified.journals < 1 || verified.entries < 0 ||
          verified.revisions < 0 || verified.attachments < 0) {
        throw const FictionalActivationRejected();
      }
      injectFailure?.call('after_candidate_verified_before_activation');

      if (await _kind(_active(trustedPrivateRoot).path) !=
              FileSystemEntityType.notFound ||
          await _kind(_reservation(trustedPrivateRoot).path) !=
              FileSystemEntityType.notFound) {
        throw const FictionalActivationRejected();
      }
      // The exclusive-create reservation is permanent even on failure.
      await _reservation(trustedPrivateRoot).create(exclusive: true);
      injectFailure?.call('after_activation_reservation');

      await NativeRestorePublisher().activateApprovedFictionalCandidate(
        candidate: _candidate(trustedPrivateRoot),
        activeDestination: _active(trustedPrivateRoot),
        exclusiveActivationReservation: _reservation(trustedPrivateRoot),
        injectFailure: injectFailure,
      );
      injectFailure?.call('after_activation_publication');

      // Independent unlock of the *moved* encrypted DB with the SAME native
      // AndroidKeyStore alias and saved envelope, no external archive/key.
      final reopened = await reopenActivated(
        trustedPrivateRoot: trustedPrivateRoot,
        deviceProtector: deviceProtector,
      );
      if (reopened.journals != verified.journals ||
          reopened.entries != verified.entries ||
          reopened.revisions != verified.revisions ||
          reopened.attachments != verified.attachments) {
        throw const FictionalActivationRejected();
      }
      return reopened;
    } catch (_) {
      // Any error after no-replace rename is AMBIGUOUS. Preserve both
      // candidate and/or promoted active directory, plus all reservations.
      throw const FictionalActivationRejected();
    }
  }

  static Future<FictionalActivationReceipt> reopenActivated({
    required Directory trustedPrivateRoot,
    required DeviceKeyProtector deviceProtector,
  }) async {
    Uint8List? bytes;
    TestVaultKey? key;
    JournalEditorWorker? worker;
    RecoveryKey? probeKey;
    Uint8List? archive;
    try {
      if (const bool.fromEnvironment('dart.vm.product') ||
          await inspect(trustedPrivateRoot: trustedPrivateRoot) !=
              FictionalActivationState.activeFictionalVault) {
        throw const FictionalActivationRejected();
      }
      final active = _active(trustedPrivateRoot);
      final db = active.path + '/vault/journal.sqlite3';
      final envelope = KeyEnvelopeCoordinator(
        envelopeFile: File(active.path + '/envelope.json'),
        protector: deviceProtector,
      );
      bytes = await envelope.unlock(databasePath: db);
      key = TestVaultKey.fromBytes(bytes);
      worker = await JournalEditorWorker.open(db, key: key);
      if (!await worker.integrityCheck()) {
        throw const FictionalActivationRejected();
      }
      // Authenticate a fresh snapshot of the COMPLETE encrypted schema:
      // journal names, entries, revisions, trash and attachments. It remains
      // in memory and is never returned to UI or written in plaintext.
      probeKey = RecoveryKey.random();
      archive = await worker.exportRecoveryArchive(probeKey);
      final snapshot = await ProductEncryptedArchiveCodec().verify(
        archive: archive, recoveryKey: probeKey);
      final journals = (snapshot['journals'] as List).length;
      final entries = (snapshot['entries'] as List).length;
      final revisions = (snapshot['revisions'] as List).length;
      final attachments = (snapshot['attachments'] as List).length;
      if (journals < 1) throw const FictionalActivationRejected();

      return FictionalActivationReceipt(
        journals: journals,
        entries: entries,
        revisions: revisions,
        attachments: attachments,
      );
    } catch (_) {
      throw const FictionalActivationRejected();
    } finally {
      try {
        await worker?.close();
      } finally {
        archive?.fillRange(0, archive.length, 0);
        probeKey?.destroy();
        key?.destroy();
        bytes?.fillRange(0, bytes.length, 0);
      }
    }
  }
}
