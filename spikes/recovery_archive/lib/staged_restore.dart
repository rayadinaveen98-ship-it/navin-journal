/// A4.2 TEST-ONLY: authenticated archive -> newly encrypted SQLite vault.
/// Fictional data only. No real device, iOS, keychain or production restore.
///
/// Contract: verify the portable archive FIRST; prepare a distinct encrypted
/// SQLite3MultipleCiphers vault in a temporary sibling directory; transactionally
/// insert entries and media blobs; close and independently reopen/check every
/// byte; finally promote the directory. Existing targets are never intentionally
/// opened, merged, deleted or overwritten. Native fsync/race hardening is pending.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:sqlite3/sqlite3.dart';

import 'recovery_archive.dart';

class RestoreRejected implements Exception {
  const RestoreRejected();
  @override
  String toString() => 'RestoreRejected';
}

class StagedRestoreReceipt {
  final String directory;
  final int entries;
  final int attachments;
  const StagedRestoreReceipt(this.directory, this.entries, this.attachments);
}

class RestoredTestVault {
  static const databaseName = 'journal.sqlite3';
  static const identity = 'NAVIN_RESTORE_SPIKE_TEST_ONLY_V1';
  final Database _db;
  bool _closed = false;

  RestoredTestVault._(this._db);

  static RestoredTestVault _connect(String path, TestVaultKey key,
      {required bool create}) {
    final file = File(path);
    if (create && file.existsSync()) throw const RestoreRejected();
    if (!create && !file.existsSync()) throw const RestoreRejected();

    // Reuse the same SQLite3MultipleCiphers build check as the A2 spike.
    // Ordinary SQLite ignores unknown cipher pragmas; fail before creating
    // schema or changing an existing vault.
    final hex = key.hex;
    Database? db;
    try {
      db = sqlite3.open(path);
      final cipher = db.select('PRAGMA cipher');
      if (cipher.isEmpty || cipher.first.columnAt(0) == null) {
        throw CryptoBackendUnavailable();
      }
      db.execute("PRAGMA cipher = 'chacha20'");
      db.execute("PRAGMA hexkey = '$hex'");
      try {
        db.select('SELECT name FROM sqlite_master LIMIT 1');
      } on SqliteException {
        throw const RestoreRejected();
      }
      final opened = RestoredTestVault._(db);
      if (!create) opened._verifyIdentity();

      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 5000');
      // DELETE journal mode allows a single-file encrypted DB after a
      // committed stage closes; no WAL/SHM sidecar during promotion.
      db.execute('PRAGMA journal_mode = DELETE');
      db.execute('PRAGMA synchronous = FULL');
      if (create) opened._initialize();
      return opened;
    } catch (_) {
      db?.close();
      rethrow;
    }
  }

  static RestoredTestVault open(
    String directory, {
    required TestVaultKey key,
  }) => _connect(
        File(directory).path + Platform.pathSeparator + databaseName,
        key,
        create: false,
      );

  void _ensureOpen() {
    if (_closed) throw StateError('Restored test vault is closed');
  }

  void _initialize() {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('CREATE TABLE restore_identity (marker TEXT NOT NULL) STRICT');
      _db.execute('INSERT INTO restore_identity(marker) VALUES (?)', [identity]);
      _db.execute('''
        CREATE TABLE restored_entries (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL
        ) STRICT
      ''');
      _db.execute('''
        CREATE TABLE restored_media (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          mime TEXT NOT NULL,
          bytes BLOB NOT NULL,
          digest TEXT NOT NULL
        ) STRICT
      ''');
      _db.userVersion = 1;
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _verifyIdentity() {
    try {
      if (_db.userVersion != 1) throw const RestoreRejected();
      final identityRows = _db.select('SELECT marker FROM restore_identity');
      if (identityRows.length != 1 ||
          identityRows.single['marker'] != identity) {
        throw const RestoreRejected();
      }
    } on SqliteException {
      throw const RestoreRejected();
    }
  }

  void insertAll(
    VerifiedRecoveryArchive snapshot,
    Map<String, String> attachmentHashes, {
    void Function(String checkpoint)? injectFailure,
  }) {
    _ensureOpen();
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final entry in snapshot.entries) {
        _db.execute(
          'INSERT INTO restored_entries(id, title, body) VALUES (?, ?, ?)',
          [entry.id, entry.title, entry.body],
        );
        injectFailure?.call('after_entry');
      }
      for (final media in snapshot.attachments) {
        _db.execute(
          'INSERT INTO restored_media(id, name, mime, bytes, digest) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            media.id,
            media.name,
            media.mimeType,
            media.bytes,
            attachmentHashes[media.id],
          ],
        );
        injectFailure?.call('after_attachment');
      }
      injectFailure?.call('before_commit');
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  List<PortableEntry> readEntries() {
    _ensureOpen();
    return _db
        .select('SELECT id, title, body FROM restored_entries ORDER BY id')
        .map((r) => PortableEntry(
              id: r['id'] as String,
              title: r['title'] as String,
              body: r['body'] as String,
            ))
        .toList(growable: false);
  }

  List<PortableAttachment> readAttachments() {
    _ensureOpen();
    return _db
        .select('SELECT id, name, mime, bytes FROM restored_media ORDER BY id')
        .map((r) => PortableAttachment(
              id: r['id'] as String,
              name: r['name'] as String,
              mimeType: r['mime'] as String,
              bytes: Uint8List.fromList(r['bytes'] as List<int>),
            ))
        .toList(growable: false);
  }

  Map<String, String> readHashes() {
    _ensureOpen();
    return {
      for (final r in _db.select('SELECT id, digest FROM restored_media'))
        r['id'] as String: r['digest'] as String,
    };
  }

  bool integrityCheck() {
    _ensureOpen();
    return _db.select('PRAGMA integrity_check').single.columnAt(0) == 'ok' &&
        _db.select('PRAGMA foreign_key_check').isEmpty;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }
}

class StagedRecoveryRestorer {
  final RecoveryArchiveCodec codec;
  final void Function(String checkpoint)? injectFailure;
  final _sha = Sha256();

  StagedRecoveryRestorer({
    RecoveryArchiveCodec? codec,
    this.injectFailure,
  }) : codec = codec ?? RecoveryArchiveCodec();

  /// Restores ONLY to a brand-new directory, always using a NEW independent
  /// 32-byte encrypted SQLite test key. No source vault, Keystore alias or
  /// production state is read or modified. The caller must handle key custody.
  ///
  /// The archive is authenticated and fully parsed before disk staging. All
  /// entries/media are committed in ONE transaction to an encrypted SQLite
  /// file in a same-parent temporary directory; it is closed and reopened
  /// to verify exact content and digests before directory rename.
  Future<StagedRestoreReceipt> restoreNew({
    required Uint8List encryptedArchive,
    required RecoveryKey recoveryKey,
    required TestVaultKey destinationKey,
    required Directory destination,
  }) async {
    // verify() has NO destination or disk write side effects.
    final snapshot = await codec.verify(
      key: recoveryKey,
      archive: encryptedArchive,
    );

    if (destination.path.trim().isEmpty) throw const RestoreRejected();
    if (await destination.exists() ||
        await File(destination.path).exists() ||
        await Link(destination.path).exists()) {
      throw const RestoreRejected();
    }
    final parent = destination.parent;
    if (!await parent.exists()) throw const RestoreRejected();

    final hashes = <String, String>{};
    for (final media in snapshot.attachments) {
      final digest = await _sha.hash(media.bytes);
      hashes[media.id] = base64Encode(digest.bytes);
    }
    Directory? staging;
    bool promoted = false;
    RestoredTestVault? writer;
    try {
      staging = await parent.createTemp('.nj-restore-stage-');
      injectFailure?.call('after_stage_created');

      final databaseFile =
          staging.path + Platform.pathSeparator + RestoredTestVault.databaseName;
      writer = RestoredTestVault._connect(
        databaseFile,
        destinationKey,
        create: true,
      );
      injectFailure?.call('after_encrypted_database_created');

      writer.insertAll(snapshot, hashes, injectFailure: injectFailure);
      writer.close();
      writer = null;
      injectFailure?.call('after_commit_before_verify');

      final check = RestoredTestVault.open(staging.path, key: destinationKey);
      try {
        if (!check.integrityCheck()) throw const RestoreRejected();
        final expectedEntries = [...snapshot.entries]
          ..sort((a, b) => a.id.compareTo(b.id));
        final actualEntries = check.readEntries();
        if (actualEntries.length != expectedEntries.length) {
          throw const RestoreRejected();
        }
        for (var i = 0; i < expectedEntries.length; i++) {
          if (actualEntries[i] != expectedEntries[i]) {
            throw const RestoreRejected();
          }
        }
        final expectedMedia = [...snapshot.attachments]
          ..sort((a, b) => a.id.compareTo(b.id));
        final actualMedia = check.readAttachments();
        if (actualMedia.length != expectedMedia.length) {
          throw const RestoreRejected();
        }
        final persistedHashes = check.readHashes();
        for (var i = 0; i < expectedMedia.length; i++) {
          final e = expectedMedia[i];
          final a = actualMedia[i];
          if (e.id != a.id ||
              e.name != a.name ||
              e.mimeType != a.mimeType ||
              !listEquals(e.bytes, a.bytes) ||
              persistedHashes[e.id] != hashes[e.id]) {
            throw const RestoreRejected();
          }
        }
      } finally {
        check.close();
      }

      injectFailure?.call('after_verify_before_promotion');
      // The target still must not exist. Directory rename can be atomic on
      // a local filesystem; neither this check nor rename is a race-free
      // no-replace primitive. Production needs native renameat2/fsync locks.
      if (await destination.exists() ||
          await File(destination.path).exists() ||
          await Link(destination.path).exists()) {
        throw const RestoreRejected();
      }
      await staging.rename(destination.path);
      promoted = true;
      return StagedRestoreReceipt(
        destination.path,
        snapshot.entries.length,
        snapshot.attachments.length,
      );
    } catch (_) {
      // No silent recovery by replacing existing journal contents.
      throw const RestoreRejected();
    } finally {
      writer?.close();
      if (!promoted && staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
