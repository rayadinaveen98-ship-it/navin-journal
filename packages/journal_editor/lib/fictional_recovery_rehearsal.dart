/// APK 02 fictional-only encrypted recovery rehearsal.
///
/// Performs a genuine v2 encrypted snapshot/export and a fresh, independent
/// encrypted restore on a separate worker. The rehearsal is EXPLICITLY not
/// an external backup or a user recovery workflow. Only synthetic fixture
/// data is allowed. No archive/recovery key leaves process memory, and a
/// completely new disposable directory is used instead of an active vault.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_editor_isolate.dart';
import 'portable_recovery_worker.dart';

class RecoveryRehearsalUnavailable implements Exception {
  const RecoveryRehearsalUnavailable();
  @override
  String toString() => 'RecoveryRehearsalUnavailable';
}

/// Contains only nonsecret aggregate counts. It is not a recovery receipt
/// for a user's vault: no external archive, key custody, or persistent restored
/// vault exists once rehearsal finishes.
class FictionalRecoveryRehearsalReport {
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;

  const FictionalRecoveryRehearsalReport({
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
  });

  bool get isOffDeviceBackup => false;
  bool get replacedActiveJournal => false;
}

class FictionalRecoveryRehearsal {
  const FictionalRecoveryRehearsal._();

  /// Call only while the scripted fictional editor is not open. No user text,
  /// recovery key, journal metadata or file paths are logged or returned.
  ///
  /// The staging engine is tested using a freshly generated destination key
  /// inside an owned temporary root. Restoration is followed by an
  /// independent encrypted SQLite worker reopen. The temporary directory
  /// is explicitly cleaned up even on failure. Recovery keys are destroyed
  /// and the ciphertext buffer is zeroed at the end.
  ///
  /// This DOES NOT prove recovery after uninstall/device loss: it neither
  /// exports a user-held archive nor provisions durable new-device key custody.
  static Future<FictionalRecoveryRehearsalReport> run({
    required JournalEditorWorker source,
  }) async {
    if (const bool.fromEnvironment('dart.vm.product')) {
      throw const RecoveryRehearsalUnavailable();
    }
    final recoveryKey = RecoveryKey.random();
    final destinationKey = TestVaultKey.random();
    Uint8List? ciphertext;
    Directory? ownedRoot;
    JournalEditorWorker? restoredWorker;
    try {
      // Source worker owns the encrypted original database. Export is a
      // consistent full-schema snapshot, encrypted with an INDEPENDENT key.
      ciphertext = await source.exportRecoveryArchive(recoveryKey);
      ownedRoot = await Directory.systemTemp.createTemp(
          'nj-fictional-recovery-rehearsal-');
      final newVault = Directory(ownedRoot.path +
          Platform.pathSeparator + 'new-encrypted-vault');
      final receipt = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: ciphertext,
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: newVault,
      );
      // The native restore publisher refuses collisions; reopening through
      // the same single-owner worker catches missing/corrupt published data.
      restoredWorker = await JournalEditorWorker.open(
        newVault.path + Platform.pathSeparator + 'journal.sqlite3',
        key: destinationKey,
      );
      if (!await restoredWorker.integrityCheck()) {
        throw const RecoveryRehearsalUnavailable();
      }
      final journals = await restoredWorker.listJournals(includeTrash: true);
      final entries = await restoredWorker.listEntries(includeTrash: true);
      final journalIds = journals.map((j) => j['id']).toSet();
      if (journals.length != receipt.journals ||
          entries.length != receipt.entries ||
          entries.any((e) => !journalIds.contains(e['journalId']))) {
        throw const RecoveryRehearsalUnavailable();
      }
      var historyCount = 0;
      for (final row in entries) {
        historyCount += await restoredWorker.historyCount(row['id'] as String);
      }
      if (historyCount != receipt.revisions) {
        throw const RecoveryRehearsalUnavailable();
      }
      return FictionalRecoveryRehearsalReport(
        journals: receipt.journals,
        entries: receipt.entries,
        revisions: receipt.revisions,
        attachments: receipt.attachments,
      );
    } catch (_) {
      // Deliberately omit sensitive exception text and original file paths.
      throw const RecoveryRehearsalUnavailable();
    } finally {
      try {
        await restoredWorker?.close();
      } finally {
        try {
          // Only this method's freshly created disposable directory.
          // Never enumerate or clean orphaned restoration candidates.
          if (ownedRoot != null && await ownedRoot.exists()) {
            await ownedRoot.delete(recursive: true);
          }
        } finally {
          ciphertext?.fillRange(0, ciphertext.length, 0);
          recoveryKey.destroy();
          destinationKey.destroy();
        }
      }
    }
  }
}
