/// A4.3.4a FULL-SCHEMA staged restore experiment — fictional data ONLY.
///
/// Authenticating the v2 archive happens before any disk staging. All journals,
/// entries, historical versions, Trash metadata and media are inserted into a
/// separately keyed SQLite3MultipleCiphers vault in one SQL transaction.
/// After independent close/reopen verification, publish into a NEW directory.
///
/// Uses native no-clobber rename and file/directory sync on Linux/Android.
/// NOT PRODUCTION: power-loss proof, Android key custody, media streaming,
/// migrations and an independent security review remain open.
/// Never use this with real private writing or with an existing user vault.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_vault.dart';
import 'native_restore_publisher.dart';

class ProductRestoreRejected implements Exception {
  const ProductRestoreRejected();
  @override
  String toString() => 'ProductRestoreRejected';
}

class ProductRestoreReceipt {
  final String directory;
  final int journals;
  final int entries;
  final int revisions;
  final int attachments;
  const ProductRestoreReceipt({
    required this.directory,
    required this.journals,
    required this.entries,
    required this.revisions,
    required this.attachments,
  });
}

class StagedProductRestorer {
  static const databaseName = 'journal.sqlite3';

  final ProductEncryptedArchiveCodec codec;
  final void Function(String checkpoint)? injectFailure;

  StagedProductRestorer({ProductEncryptedArchiveCodec? codec, this.injectFailure})
      : codec = codec ?? ProductEncryptedArchiveCodec();

  Future<ProductRestoreReceipt> restoreNew({
    required Uint8List encryptedArchive,
    required RecoveryKey recoveryKey,
    required TestVaultKey destinationKey,
    required Directory destination,
  }) async {
    // Crucial: no filesystem side effects until the entire v2 payload has
    // been authenticated and its relationships/media hashes validated.
    final source = await codec.verify(
      recoveryKey: recoveryKey,
      archive: encryptedArchive,
    );
    if (destination.path.trim().isEmpty || await _occupied(destination)) {
      throw const ProductRestoreRejected();
    }
    final parent = destination.parent;
    if (!await parent.exists()) throw const ProductRestoreRejected();

    JournalVault? writer;
    Directory? staging;
    var published = false;
    try {
      staging = await parent.createTemp('.navin-journal-restore-');
      injectFailure?.call('after_stage_created');
      final dbPath = staging.path + Platform.pathSeparator + databaseName;
      writer = JournalVault.open(dbPath,
        key: destinationKey,
        create: true,
        injectFailure: injectFailure,
      );
      injectFailure?.call('after_encrypted_database_created');
      await writer.importIntoEmpty(source);
      writer.close();
      writer = null;
      injectFailure?.call('after_commit_before_verify');

      final verifier = JournalVault.open(dbPath, key: destinationKey);
      try {
        if (!verifier.integrityCheck()) throw const ProductRestoreRejected();
        final reopened = verifier.snapshot();
        await ProductSnapshotCodec().validate(reopened);
        if (!_equivalentSnapshots(source, reopened)) {
          throw const ProductRestoreRejected();
        }
      } finally {
        verifier.close();
      }

      injectFailure?.call('after_verify_before_promotion');
      // The early collision check is only a fast guard. The native kernel
      // RENAME_NOREPLACE operation is the actual concurrent-write boundary.
      // Sync the staged encrypted DB, WAL/SHM and directory first; a complete
      // readiness marker is published in the same atomic directory rename.
      if (await _occupied(destination)) throw const ProductRestoreRejected();
      await NativeRestorePublisher().publish(
        staging: staging, destination: destination,
        injectFailure: injectFailure,
      );
      published = true;
      return ProductRestoreReceipt(
        directory: destination.path,
        journals: (source['journals'] as List).length,
        entries: (source['entries'] as List).length,
        revisions: (source['revisions'] as List).length,
        attachments: (source['attachments'] as List).length,
      );
    } catch (_) {
      throw const ProductRestoreRejected();
    } finally {
      writer?.close();
      if (!published && staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  static Future<bool> _occupied(Directory destination) async =>
      await destination.exists() ||
      await File(destination.path).exists() ||
      await Link(destination.path).exists();

  static bool _equivalentSnapshots(
    Map<String, dynamic> expected,
    Map<String, dynamic> actual,
  ) {
    for (final group in ['journals', 'entries', 'revisions', 'attachments']) {
      final e = [...expected[group] as List];
      final a = [...actual[group] as List];
      if (e.length != a.length) return false;
      int byId(dynamic first, dynamic second) {
        final x = first as Map;
        final y = second as Map;
        if (group == 'revisions') {
          final firstEntry = (x['entryId'] as String).compareTo(y['entryId'] as String);
          if (firstEntry != 0) return firstEntry;
          return (x['version'] as int).compareTo(y['version'] as int);
        }
        return (x['id'] as String).compareTo(y['id'] as String);
      }
      e.sort(byId);
      a.sort(byId);
      for (var i = 0; i < e.length; i++) {
        if (!_same(e[i], a[i])) return false;
      }
    }
    return true;
  }

  static bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length || !a.keys.toSet().containsAll(b.keys)) {
        return false;
      }
      for (final key in a.keys) {
        if (!_same(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_same(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
