/// STAGE 4 A2 — SQLCipher/SQLite3MultipleCiphers **EXPERIMENT ONLY**.
///
/// Important: This is NOT a production private vault. Test-fixture content only.
/// The caller supplies a high-entropy key. No Android Keystore/Keychain,
/// secret persistence, recovery, lifecycle safety, media encryption or audit.
/// The code MUST fail closed if the encryption-capable SQLite library is absent.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

class CryptoBackendUnavailable implements Exception {
  @override
  String toString() => 'Encryption-enabled SQLite library unavailable';
}

class VaultUnlockFailed implements Exception {
  @override
  String toString() => 'Vault could not be opened with the supplied key';
}

/// In-memory test material only. Real key storage and wipe semantics are TBD.
/// A Dart String created for PRAGMA cannot be reliably zeroed from memory.
class TestVaultKey {
  final Uint8List _data;
  bool _destroyed = false;

  TestVaultKey.fromBytes(List<int> bytes)
      : _data = Uint8List.fromList(bytes) {
    if (_data.length != 32) {
      throw ArgumentError('Exactly 32 bytes of key material are required');
    }
  }

  factory TestVaultKey.random() {
    final rng = Random.secure();
    return TestVaultKey.fromBytes(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
  }

  String get hex {
    if (_destroyed) throw StateError('Test key was destroyed');
    return _data
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  void destroy() {
    _data.fillRange(0, _data.length, 0);
    _destroyed = true;
  }

  @override
  String toString() => 'TestVaultKey([REDACTED])';
}

/// Only a minimal demonstration of encrypted database contents and revisions.
class EncryptedJournalSpike {
  final Database _db;
  final void Function(String point)? failureHook;

  EncryptedJournalSpike._(this._db, this.failureHook);

  static const appMarker = 'NAVIN_EXPERIMENT_ENCRYPTED_SCHEMA_1';

  /// If [create] is true, refuse to overwrite even a partially created file.
  ///
  /// [key] must be supplied by the caller. Never hardcode it in an app, store
  /// it in source control or log SQL containing the PRAGMA hexkey command.
  static EncryptedJournalSpike open(
    String filePath, {
    required TestVaultKey key,
    bool create = false,
    void Function(String point)? failureHook,
  }) {
    if (filePath.trim().isEmpty) throw ArgumentError('Path required');
    final target = File(filePath);
    if (create && target.existsSync()) {
      throw StateError('Refusing to overwrite an existing vault');
    }
    if (!create && !target.existsSync()) {
      throw StateError('Vault file does not exist; refusing to create');
    }
    if (create) target.parent.createSync(recursive: true);

    // Reject a destroyed key before even opening the file.
    final hex = key.hex;
    Database? db;
    try {
      db = sqlite3.open(filePath);

      // Unknown SQLite PRAGMAs are silently ignored by standard SQLite.
      // Verify that SQLite3MultipleCiphers really is in the process.
      final cipher = db.select('PRAGMA cipher');
      if (cipher.isEmpty || cipher.first.columnAt(0) == null) {
        throw CryptoBackendUnavailable();
      }
      db.execute("PRAGMA cipher = 'chacha20'");
      db.execute("PRAGMA hexkey = '$hex'");

      // PRAGMA hexkey can report success even with a wrong key; force an
      // actual schema read. Do not run migrations after failure.
      try {
        db.select('SELECT name FROM sqlite_master LIMIT 1');
      } on SqliteException {
        throw VaultUnlockFailed();
      }

      // These are applied *after* successful key activation and schema read.
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');

      final store = EncryptedJournalSpike._(db, failureHook);
      if (create) {
        store._initialize();
      } else {
        store._verifyAppMarker();
      }
      return store;
    } catch (_) {
      db?.close();
      rethrow;
    }
  }

  void close() => _db.close();

  void _transaction(void Function() work) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      work();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _initialize() {
    _transaction(() {
      _db.execute('''
        CREATE TABLE vault_marker (
          marker TEXT NOT NULL CHECK(length(marker) > 0)
        ) STRICT
      ''');
      _db.execute('INSERT INTO vault_marker(marker) VALUES (?)', [appMarker]);
      _db.execute('''
        CREATE TABLE private_entries (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          version INTEGER NOT NULL CHECK(version > 0)
        ) STRICT
      ''');
      _db.execute('''
        CREATE TABLE private_revisions (
          entry_id TEXT NOT NULL REFERENCES private_entries(id),
          version INTEGER NOT NULL,
          body TEXT NOT NULL,
          PRIMARY KEY(entry_id, version)
        ) STRICT
      ''');
      _db.userVersion = 1;
    });
  }

  void _verifyAppMarker() {
    try {
      if (_db.userVersion != 1) {
        throw StateError('Unsupported encrypted vault schema');
      }
      final rows = _db.select('SELECT marker FROM vault_marker');
      if (rows.length != 1 || rows.single['marker'] != appMarker) {
        throw StateError('Unsupported encrypted vault identity');
      }
    } on SqliteException {
      throw VaultUnlockFailed();
    }
  }

  void insertFictionalEntry({
    required String id,
    required String title,
    required String body,
  }) {
    if (id.isEmpty || (title.trim().isEmpty && body.trim().isEmpty)) {
      throw ArgumentError('A meaningful test entry and stable ID are required');
    }
    _transaction(() {
      _db.execute(
        'INSERT INTO private_entries(id, title, body, version) '
        'VALUES (?, ?, ?, 1)',
        [id, title, body],
      );
    });
  }

  String? entryBody(String id) {
    final rows = _db.select(
      'SELECT body FROM private_entries WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : rows.first['body'] as String;
  }

  int entryVersion(String id) {
    final rows = _db.select(
      'SELECT version FROM private_entries WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) throw StateError('Entry does not exist');
    return rows.first['version'] as int;
  }

  void editFictionalEntry({
    required String id,
    required int expectedVersion,
    required String body,
  }) {
    _transaction(() {
      final row = _db.select(
        'SELECT body, version FROM private_entries WHERE id = ?',
        [id],
      );
      if (row.isEmpty) throw StateError('Entry does not exist');
      final old = row.single;
      if (old['version'] != expectedVersion) {
        throw StateError('Conflicting existing revision');
      }
      if (old['body'] == body) return;
      _db.execute(
        'INSERT INTO private_revisions(entry_id, version, body) '
        'VALUES (?, ?, ?)',
        [id, expectedVersion, old['body']],
      );
      failureHook?.call('after_revision_before_update');
      _db.execute(
        'UPDATE private_entries SET body = ?, version = version + 1 '
        'WHERE id = ? AND version = ?',
        [body, id, expectedVersion],
      );
      if (_db.updatedRows != 1) throw StateError('Stale edit');
    });
  }

  List<String> previousBodies(String id) => _db
      .select(
        'SELECT body FROM private_revisions WHERE entry_id = ? '
        'ORDER BY version',
        [id],
      )
      .map((row) => row['body'] as String)
      .toList();

  bool integrityCheck() {
    final rows = _db.select('PRAGMA integrity_check');
    final keys = _db.select('PRAGMA foreign_key_check');
    return rows.length == 1 && rows.single.columnAt(0) == 'ok' && keys.isEmpty;
  }

  void checkpoint() => _db.select('PRAGMA wal_checkpoint(TRUNCATE)');
}
