/// Stage 4 A3.2 — encrypted SQLite commit adapter for AUTOSAVE TESTS ONLY.
///
/// This uses SQLite3MultipleCiphers for fictional data and a caller-supplied
/// test key. It has no Android key lifecycle, backups, attachments, app lock,
/// native lifecycle integration, and cannot store real private diaries.
/// Do not expose this experimental database to a consumer editor.
library;

import 'dart:io';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:sqlite3/sqlite3.dart';

import 'draft_autosave.dart';

class EncryptedDraftStore implements DraftCommitPort {
  final Database _db;
  final void Function(String checkpoint)? failureHook;
  bool _closed = false;

  EncryptedDraftStore._(this._db, this.failureHook);

  static const _identity = 'NAVIN_AUTOSAVE_TEST_ONLY_V1';

  static EncryptedDraftStore open(
    String filename, {
    required TestVaultKey key,
    bool create = false,
    void Function(String checkpoint)? failureHook,
  }) {
    if (filename.trim().isEmpty) throw ArgumentError('File path required');
    final file = File(filename);
    if (create && file.existsSync()) {
      throw StateError('Existing encrypted database cannot be reset');
    }
    if (!create && !file.existsSync()) {
      throw StateError('Encrypted database not found; no auto-creation');
    }
    if (create) file.parent.createSync(recursive: true);

    final hex = key.hex;
    Database? db;
    try {
      db = sqlite3.open(filename);
      final ciphers = db.select('PRAGMA cipher');
      if (ciphers.isEmpty || ciphers.first.columnAt(0) == null) {
        throw CryptoBackendUnavailable();
      }
      db.execute("PRAGMA cipher = 'chacha20'");
      db.execute("PRAGMA hexkey = '$hex'");
      // Unrecognized PRAGMAs in ordinary SQLite may be ignored: actually
      // read the catalog before any migration or journal-mode writes.
      try {
        db.select('SELECT name FROM sqlite_master LIMIT 1');
      } on SqliteException {
        throw VaultUnlockFailed();
      }

      final store = EncryptedDraftStore._(db, failureHook);
      if (!create) store._checkIdentity();

      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');
      if (create) store._initialize();
      return store;
    } catch (_) {
      db?.close();
      rethrow;
    }
  }

  void _transaction(void Function() action) {
    _ensureOpen();
    _db.execute('BEGIN IMMEDIATE');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _initialize() {
    _transaction(() {
      _db.execute('''
        CREATE TABLE store_identity(
          marker TEXT NOT NULL PRIMARY KEY
        ) STRICT
      ''');
      _db.execute('INSERT INTO store_identity(marker) VALUES (?)', [_identity]);
      _db.execute('''
        CREATE TABLE drafts(
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          version INTEGER NOT NULL CHECK(version > 0),
          updated_ms INTEGER NOT NULL
        ) STRICT
      ''');
      _db.execute('''
        CREATE TABLE draft_revisions(
          id TEXT NOT NULL REFERENCES drafts(id) ON DELETE RESTRICT,
          version INTEGER NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          PRIMARY KEY(id, version)
        ) STRICT
      ''');
      _db.userVersion = 1;
    });
  }

  void _checkIdentity() {
    try {
      if (_db.userVersion != 1) {
        throw StateError('Unsupported encrypted autosave schema');
      }
      final records = _db.select('SELECT marker FROM store_identity');
      if (records.length != 1 || records.single['marker'] != _identity) {
        throw StateError('Unsupported encrypted autosave identity');
      }
    } on SqliteException {
      throw VaultUnlockFailed();
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Storage connection closed');
  }

  int? getVersion(String entryId) {
    _ensureOpen();
    final found = _db.select('SELECT version FROM drafts WHERE id = ?', [entryId]);
    return found.isEmpty ? null : found.single['version'] as int;
  }

  DraftContent? read(String entryId) {
    _ensureOpen();
    final found = _db.select(
      'SELECT title, body FROM drafts WHERE id = ?', [entryId],
    );
    if (found.isEmpty) return null;
    return DraftContent(
      title: found.single['title'] as String,
      body: found.single['body'] as String,
    );
  }

  List<DraftContent> history(String entryId) {
    _ensureOpen();
    return _db
        .select(
          'SELECT title, body FROM draft_revisions '
          'WHERE id = ? ORDER BY version',
          [entryId],
        )
        .map((row) => DraftContent(
              title: row['title'] as String,
              body: row['body'] as String,
            ))
        .toList();
  }

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    if (entryId.trim().isEmpty || expectedVersion < 0) {
      throw ArgumentError('Invalid test entry/version');
    }
    // The synchronous transaction should be dispatched to a background
    // storage isolate before production Flutter editor integration.
    final committedVersion = _persist(entryId, expectedVersion, content);
    // Simulate an ACK lost AFTER the durable SQLite COMMIT. This deliberately
    // cannot roll back; retry must detect same ID/version/content safely.
    failureHook?.call('after_commit_before_ack');
    return CommitReceipt(entryId, committedVersion);
  }

  int _persist(String id, int expected, DraftContent content) {
    _ensureOpen();
    late int version;
    _transaction(() {
      final current = _db.select(
        'SELECT title, body, version FROM drafts WHERE id = ?', [id],
      );

      if (current.isEmpty) {
        if (expected != 0) throw const DraftConflict();
        if (content.isBlank) {
          throw StateError('Do not create an untouched empty draft');
        }
        _db.execute(
          'INSERT INTO drafts(id, title, body, version, updated_ms) '
          'VALUES (?, ?, ?, 1, ?)',
          [id, content.title, content.body, DateTime.now().toUtc().millisecondsSinceEpoch],
        );
        version = 1;
        return;
      }

      final row = current.single;
      final foundVersion = row['version'] as int;
      final matches = row['title'] == content.title && row['body'] == content.body;

      // Lost acknowledgement: the previous transaction already committed
      // exactly this snapshot, under this stable entry ID. A second attempt
      // must never create a duplicate or an artificial new version.
      if (foundVersion == expected + 1 && matches) {
        version = foundVersion;
        return;
      }
      if (foundVersion != expected) throw const DraftConflict();
      if (matches) {
        throw StateError('Identical committed snapshot should not be re-saved');
      }

      _db.execute(
        'INSERT INTO draft_revisions(id, version, title, body) '
        'VALUES (?, ?, ?, ?)',
        [id, foundVersion, row['title'], row['body']],
      );
      failureHook?.call('after_revision_before_update');
      _db.execute(
        'UPDATE drafts SET title = ?, body = ?, version = version + 1, '
        'updated_ms = ? WHERE id = ? AND version = ?',
        [
          content.title,
          content.body,
          DateTime.now().toUtc().millisecondsSinceEpoch,
          id,
          expected,
        ],
      );
      if (_db.updatedRows != 1) throw const DraftConflict();
      version = expected + 1;
    });
    return version;
  }

  bool integrityCheck() {
    _ensureOpen();
    final data = _db.select('PRAGMA integrity_check');
    final fk = _db.select('PRAGMA foreign_key_check');
    return data.length == 1 && data.single.columnAt(0) == 'ok' && fk.isEmpty;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }
}
