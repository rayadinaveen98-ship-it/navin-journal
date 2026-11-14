/// Read-only authenticated examination of a QUARANTINED fictional restore.
///
/// This module DOES NOT publish, delete, merge, resume, overwrite, or declare
/// any interrupted restore ready for consumer use. The staging candidate is
/// only read; its encrypted SQLite files are copied to a disposable encrypted
/// file-only inspection directory before SQLite touches them.
///
/// A validated archive + database-key match proves the *inspected copy*
/// contains the expected whole-journal records. It does NOT establish that
/// the source is stable, owned by this app, durable after a power outage,
/// or safe to promote, and its unsigned readiness marker is not trusted.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_vault.dart';
import 'native_restore_publisher.dart';
import 'staged_product_restore.dart';

enum RestoreAssessmentStatus {
  /// A separately authenticated archive exactly matches a decrypted COPY
  /// of the stage. This is still quarantined and NEVER auto-published.
  verifiedQuarantined,

  /// The stage does not contain a complete inspectable database.
  incomplete,

  /// The stage or its contained files are suspicious / exceed limits.
  blocked,

  /// The archive/recovery key cannot be authenticated.
  untrustedArchive,

  /// The copied encrypted store cannot be opened with the supplied DB key,
  /// fails integrity, or does not match the authenticated reference archive.
  notVerified,
}

class RestoreAssessment {
  final RestoreAssessmentStatus status;
  final bool publicationMarkerObserved;
  final int journalCount;
  final int entryCount;
  final int revisionCount;
  final int attachmentCount;

  const RestoreAssessment({
    required this.status,
    required this.publicationMarkerObserved,
    this.journalCount = 0,
    this.entryCount = 0,
    this.revisionCount = 0,
    this.attachmentCount = 0,
  });

  bool get isAuthenticatedMatch =>
      status == RestoreAssessmentStatus.verifiedQuarantined;
}

class RestoreStagingAssessment {
  /// Fixed small-fixture bound; production media/streaming is not implemented.
  static const maxStageBytes = 64 * 1024 * 1024;
  static const _candidatePattern =
      r'^\.navin-journal-restore-[A-Za-z0-9_-]{6,80}$';
  static const _allowedFiles = <String>{
    StagedProductRestorer.databaseName,
    'journal.sqlite3-wal',
    'journal.sqlite3-shm',
    NativeRestorePublisher.markerName,
  };

  /// Assessment intentionally requires a single stage *basename* beneath an
  /// explicitly passed private parent; callers cannot provide arbitrary paths.
  ///
  /// The app must hold the independently retained v2 archive, recovery key,
  /// AND the original staged DB key for a meaningful comparison. Without a
  /// database key it is intentionally impossible to pronounce a stage valid.
  static Future<RestoreAssessment> assess({
    required Directory privateParent,
    required String candidateBasename,
    required Uint8List encryptedArchive,
    required RecoveryKey recoveryKey,
    required TestVaultKey stagedDatabaseKey,
  }) async {
    if (!RegExp(_candidatePattern).hasMatch(candidateBasename) ||
        encryptedArchive.isEmpty ||
        encryptedArchive.length > ProductSnapshotCodec.maxPayloadBytes * 2) {
      return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
          publicationMarkerObserved: false);
    }

    Map<String, dynamic> reference;
    try {
      // Authenticate the independent ciphertext FIRST. This never writes it.
      reference = await ProductEncryptedArchiveCodec().verify(
        recoveryKey: recoveryKey, archive: encryptedArchive);
    } catch (_) {
      return const RestoreAssessment(
          status: RestoreAssessmentStatus.untrustedArchive,
          publicationMarkerObserved: false);
    }

    final parent = privateParent.absolute;
    if (await FileSystemEntity.type(parent.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
          publicationMarkerObserved: false);
    }
    final stage = Directory(parent.path + Platform.pathSeparator +
        candidateBasename);
    if (await FileSystemEntity.type(stage.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
          publicationMarkerObserved: false);
    }

    // Do not open SQLite directly inside the abandoned stage: a normal SQLite
    // connection can create/checkpoint -wal/-shm or change file metadata.
    // All probing occurs on encrypted-file COPIES in a private temporary dir.
    Directory? inspection;
    var markerSeen = false;
    try {
      final stageFiles = await stage.list(followLinks: false).toList();
      if (stageFiles.length > _allowedFiles.length) {
        return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
            publicationMarkerObserved: false);
      }
      var total = 0;
      final sourceStats = <String, FileStat>{};
      for (final entry in stageFiles) {
        final name = entry.uri.pathSegments
            .where((segment) => segment.isNotEmpty).last;
        if (!_allowedFiles.contains(name) ||
            await FileSystemEntity.type(entry.path, followLinks: false) !=
                FileSystemEntityType.file) {
          return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
              publicationMarkerObserved: false);
        }
        final stats = await entry.stat();
        if (stats.size < 0 || stats.size > maxStageBytes - total) {
          return const RestoreAssessment(status: RestoreAssessmentStatus.blocked,
              publicationMarkerObserved: false);
        }
        total += stats.size;
        sourceStats[name] = stats;
      }

      markerSeen = sourceStats.containsKey(NativeRestorePublisher.markerName);
      if (!sourceStats.containsKey(StagedProductRestorer.databaseName)) {
        return RestoreAssessment(status: RestoreAssessmentStatus.incomplete,
            publicationMarkerObserved: markerSeen);
      }

      inspection = await Directory.systemTemp.createTemp(
          'nj-encrypted-assessment-');
      for (final name in sourceStats.keys) {
        final from = stage.path + Platform.pathSeparator + name;
        final to = inspection.path + Platform.pathSeparator + name;
        if (await FileSystemEntity.type(from, followLinks: false) !=
            FileSystemEntityType.file) {
          return RestoreAssessment(status: RestoreAssessmentStatus.blocked,
              publicationMarkerObserved: markerSeen);
        }
        await File(from).copy(to);
        final after = await File(from).stat();
        final before = sourceStats[name]!;
        if (before.size != after.size ||
            before.modified != after.modified ||
            await File(to).length() != before.size) {
          return RestoreAssessment(status: RestoreAssessmentStatus.notVerified,
              publicationMarkerObserved: markerSeen);
        }
      }
      JournalVault? reader;
      try {
        reader = JournalVault.open(
          inspection.path + Platform.pathSeparator +
              StagedProductRestorer.databaseName,
          key: stagedDatabaseKey,
        );
        if (!reader.integrityCheck()) {
          return RestoreAssessment(status: RestoreAssessmentStatus.notVerified,
              publicationMarkerObserved: markerSeen);
        }
        final recovered = reader.snapshot();
        await ProductSnapshotCodec().validate(recovered);
        if (!StagedProductRestorer.equivalentSnapshots(
            reference, recovered)) {
          return RestoreAssessment(status: RestoreAssessmentStatus.notVerified,
              publicationMarkerObserved: markerSeen);
        }
        return RestoreAssessment(
          status: RestoreAssessmentStatus.verifiedQuarantined,
          publicationMarkerObserved: markerSeen,
          journalCount: (recovered['journals'] as List).length,
          entryCount: (recovered['entries'] as List).length,
          revisionCount: (recovered['revisions'] as List).length,
          attachmentCount: (recovered['attachments'] as List).length,
        );
      } finally {
        reader?.close();
      }
    } catch (_) {
      // Wrong DB keys, damaged SQLite, unreadable files and transient races
      // must be non-committal; never claim a usable journal based on them.
      return RestoreAssessment(status: RestoreAssessmentStatus.notVerified,
          publicationMarkerObserved: markerSeen);
    } finally {
      if (inspection != null && await inspection.exists()) {
        await inspection.delete(recursive: true);
      }
    }
  }
}
