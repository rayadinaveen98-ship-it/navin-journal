/// Navin Journal · shared encrypted journal storage engine, P0 foundation.
///
/// IMPORTANT: FICTIONAL TEST DATA ONLY until Android Keystore custody, secure
/// Flutter-isolate adapter, independent restore, hardware/device tests and
/// third-party security review are complete. Do NOT use this with a real diary.
///
/// SQLite3MultipleCiphers is mandatory: ordinary SQLite must never be used as
/// a fallback. A 32-byte vault key comes from the caller (device custody TBD).
/// No keys are created/stored/logged here. No plaintext file is exported.
///
/// Entry changes use optimistic version checks and a single SQL transaction.
/// Journal + entry + revision + media snapshots are read within ONE SQLite
/// transaction and encrypted in memory with an independent recovery key.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:sqlite3/sqlite3.dart';

class JournalConflict implements Exception {
  const JournalConflict();
  @override
  String toString() => 'JournalConflict';
}

class JournalUnavailable implements Exception {
  const JournalUnavailable();
  @override
  String toString() => 'JournalUnavailable';
}

class JournalVault {
  static const schemaVersion = 1;
  static const identity = 'NAVIN_JOURNAL_CORE_V1_TEST_ONLY';
  final Database _db;
  final void Function(String checkpoint)? injectFailure;
  bool _closed = false;

  JournalVault._(this._db, this.injectFailure);

  static JournalVault open(
    String path, {
    required TestVaultKey key,
    bool create = false,
    void Function(String checkpoint)? injectFailure,
  }) {
    if (path.trim().isEmpty) throw ArgumentError('Database path required');
    final file = File(path);
    if (create && file.existsSync()) {
      throw StateError('Refusing to replace existing encrypted journal');
    }
    if (!create && !file.existsSync()) {
      throw const JournalUnavailable();
    }
    if (create) file.parent.createSync(recursive: true);
    // Force validation before opening the native SQLite handle.
    final hex = key.hex;
    Database? db;
    try {
      db = sqlite3.open(path);
      // Standard SQLite ignores unknown cipher pragmas; verify the backend.
      final supported = db.select('PRAGMA cipher');
      if (supported.isEmpty || supported.first.columnAt(0) == null) {
        throw CryptoBackendUnavailable();
      }
      db.execute("PRAGMA cipher = 'chacha20'");
      db.execute("PRAGMA hexkey = '$hex'");
      try {
        db.select('SELECT name FROM sqlite_master LIMIT 1');
      } on SqliteException {
        throw VaultUnlockFailed();
      }
      final vault = JournalVault._(db, injectFailure);
      if (!create) vault._verifyIdentity();
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');
      if (create) vault._initialize();
      return vault;
    } catch (_) {
      db?.close();
      rethrow;
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Journal vault closed');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _db.close();
  }

  void _transaction(void Function() body) {
    _ensureOpen();
    _db.execute('BEGIN IMMEDIATE');
    try {
      body();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _initialize() {
    _transaction(() {
      _db.execute('CREATE TABLE vault_identity (marker TEXT NOT NULL) STRICT');
      _db.execute('INSERT INTO vault_identity(marker) VALUES (?)', [identity]);
      _db.execute('''
        CREATE TABLE journals (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 48),
          archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
          created_at_ms INTEGER NOT NULL,
          deleted_at_ms INTEGER
        ) STRICT
      ''');
      _db.execute('''
        CREATE UNIQUE INDEX active_journal_names
        ON journals(name COLLATE NOCASE)
        WHERE deleted_at_ms IS NULL
      ''');
      _db.execute('''
        CREATE TABLE entries (
          id TEXT PRIMARY KEY NOT NULL,
          journal_id TEXT NOT NULL REFERENCES journals(id) ON DELETE RESTRICT,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          created_at_ms INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          event_at_ms INTEGER,
          version INTEGER NOT NULL CHECK(version >= 1),
          deleted_at_ms INTEGER
        ) STRICT
      ''');
      _db.execute('''
        CREATE INDEX active_entries_by_journal
        ON entries(journal_id, deleted_at_ms, updated_at_ms DESC)
      ''');
      _db.execute('''
        CREATE TABLE revisions (
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE RESTRICT,
          version INTEGER NOT NULL,
          journal_id TEXT NOT NULL REFERENCES journals(id) ON DELETE RESTRICT,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          event_at_ms INTEGER,
          updated_at_ms INTEGER NOT NULL,
          PRIMARY KEY(entry_id, version)
        ) STRICT
      ''');
      _db.execute('''
        CREATE TABLE attachments (
          id TEXT PRIMARY KEY NOT NULL,
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE RESTRICT,
          name TEXT NOT NULL,
          mime TEXT NOT NULL,
          bytes BLOB NOT NULL,
          sha256 TEXT NOT NULL
        ) STRICT
      ''');
      _db.userVersion = schemaVersion;
    });
  }

  void _verifyIdentity() {
    try {
      if (_db.userVersion != schemaVersion) {
        throw const JournalUnavailable();
      }
      final marker = _db.select('SELECT marker FROM vault_identity');
      if (marker.length != 1 || marker.single['marker'] != identity) {
        throw const JournalUnavailable();
      }
    } on SqliteException {
      throw const JournalUnavailable();
    }
  }

  static final _rng = Random.secure();
  static String _id() => List<int>.generate(16, (_) => _rng.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static String _name(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean.runes.length > 48) {
      throw ArgumentError('Journal name must be 1–48 characters');
    }
    return clean;
  }

  String createJournal(String name) {
    final id = _id();
    final clean = _name(name);
    _transaction(() {
      _db.execute(
        'INSERT INTO journals(id,name,archived,created_at_ms) '
        'VALUES(?,?,0,?)',
        [id, clean, _now()],
      );
    });
    return id;
  }

  void renameJournal(String id, String name) {
    final clean = _name(name);
    _transaction(() {
      _db.execute(
        'UPDATE journals SET name = ? WHERE id = ? AND deleted_at_ms IS NULL',
        [clean, id],
      );
      if (_db.updatedRows != 1) throw const JournalUnavailable();
    });
  }

  void archiveJournal(String id, {required bool archived}) {
    _transaction(() {
      _db.execute(
        'UPDATE journals SET archived = ? '
        'WHERE id = ? AND deleted_at_ms IS NULL',
        [archived ? 1 : 0, id],
      );
      if (_db.updatedRows != 1) throw const JournalUnavailable();
    });
  }

  void trashJournal(String id) {
    _transaction(() {
      final rows = _db.select(
        'SELECT created_at_ms FROM journals '
        'WHERE id = ? AND deleted_at_ms IS NULL', [id],
      );
      if (rows.isEmpty) throw const JournalUnavailable();
      final created = rows.single['created_at_ms'] as int;
      _db.execute(
        'UPDATE journals SET deleted_at_ms = ? WHERE id = ?',
        [max(created, _now()), id],
      );
    });
  }

  void restoreJournal(String id) {
    _transaction(() {
      _db.execute(
        'UPDATE journals SET deleted_at_ms = NULL '
        'WHERE id = ? AND deleted_at_ms IS NOT NULL',
        [id],
      );
      if (_db.updatedRows != 1) throw const JournalUnavailable();
    });
  }

  void _requireWritableJournal(String id) {
    final found = _db.select(
      'SELECT archived, deleted_at_ms FROM journals WHERE id = ?', [id],
    );
    if (found.isEmpty ||
        found.single['archived'] != 0 ||
        found.single['deleted_at_ms'] != null) {
      throw const JournalUnavailable();
    }
  }

  static void _checkText(String title, String body) {
    if (title.runes.length > ProductSnapshotCodec.maxTextChars ||
        body.runes.length > ProductSnapshotCodec.maxTextChars) {
      throw ArgumentError('Entry exceeds test-fixture text limit');
    }
    if (title.trim().isEmpty && body.trim().isEmpty) {
      throw ArgumentError('Untouched empty entries are not committed');
    }
  }

  String createEntry({
    required String journalId,
    required String title,
    required String body,
    int? eventAtMs,
  }) {
    _checkText(title, body);
    final id = _id();
    _transaction(() {
      _requireWritableJournal(journalId);
      final now = _now();
      _db.execute('''
        INSERT INTO entries(
          id,journal_id,title,body,created_at_ms,updated_at_ms,
          event_at_ms,version,deleted_at_ms
        ) VALUES(?,?,?,?,?,?,?,1,NULL)
      ''', [id, journalId, title, body, now, now, eventAtMs]);
    });
    return id;
  }

  int entryVersion(String id) {
    _ensureOpen();
    final rows = _db.select('SELECT version FROM entries WHERE id = ?', [id]);
    if (rows.isEmpty) throw const JournalUnavailable();
    return rows.single['version'] as int;
  }

  Map<String, dynamic>? readEntry(String id) {
    _ensureOpen();
    final rows = _db.select('SELECT * FROM entries WHERE id = ?', [id]);
    return rows.isEmpty ? null : _entry(rows.single);
  }

  List<Map<String, dynamic>> listEntries({String? journalId, bool includeTrash = false}) {
    _ensureOpen();
    final rows = _db.select('''
      SELECT e.* FROM entries e
      JOIN journals j ON j.id=e.journal_id
      WHERE (? IS NULL OR e.journal_id = ?)
        AND (?=1 OR (e.deleted_at_ms IS NULL AND j.deleted_at_ms IS NULL))
      ORDER BY e.updated_at_ms DESC, e.id
    ''', [journalId, journalId, includeTrash ? 1 : 0]);
    return rows.map(_entry).toList(growable: false);
  }

  void _storeRevision(Row old) {
    _db.execute('''
      INSERT INTO revisions(
        entry_id,version,journal_id,title,body,event_at_ms,updated_at_ms
      ) VALUES (?,?,?,?,?,?,?)
    ''', [
      old['id'], old['version'], old['journal_id'], old['title'],
      old['body'], old['event_at_ms'], old['updated_at_ms'],
    ]);
  }

  /// No-op edits preserve revision number; stale versions always conflict.
  int editEntry({
    required String id,
    required int expectedVersion,
    required String journalId,
    required String title,
    required String body,
    required int? eventAtMs,
  }) {
    _checkText(title, body);
    var version = expectedVersion;
    _transaction(() {
      final rows = _db.select('SELECT * FROM entries WHERE id = ?', [id]);
      if (rows.isEmpty || rows.single['deleted_at_ms'] != null) {
        throw const JournalUnavailable();
      }
      final old = rows.single;
      if (old['version'] != expectedVersion) throw const JournalConflict();
      _requireWritableJournal(journalId);
      if (old['title'] == title &&
          old['body'] == body &&
          old['journal_id'] == journalId &&
          old['event_at_ms'] == eventAtMs) {
        return;
      }
      _storeRevision(old);
      injectFailure?.call('after_revision_before_update');
      _db.execute('''
        UPDATE entries SET journal_id=?, title=?, body=?, event_at_ms=?,
          updated_at_ms=?, version=version+1
        WHERE id=? AND version=? AND deleted_at_ms IS NULL
      ''', [
        journalId, title, body, eventAtMs,
        max(_now(), old['updated_at_ms'] as int), id, expectedVersion,
      ]);
      if (_db.updatedRows != 1) throw const JournalConflict();
      version++;
    });
    return version;
  }

  int trashEntry(String id, {required int expectedVersion}) {
    var version = expectedVersion;
    _transaction(() {
      final rows = _db.select('SELECT * FROM entries WHERE id = ?', [id]);
      if (rows.isEmpty || rows.single['deleted_at_ms'] != null) {
        throw const JournalUnavailable();
      }
      final old = rows.single;
      if (old['version'] != expectedVersion) throw const JournalConflict();
      _storeRevision(old);
      final now = max(_now(), old['updated_at_ms'] as int);
      _db.execute('''
        UPDATE entries SET version=version+1, updated_at_ms=?,
          deleted_at_ms=? WHERE id=? AND version=?
      ''', [now, max(now, old['created_at_ms'] as int), id, expectedVersion]);
      if (_db.updatedRows != 1) throw const JournalConflict();
      version++;
    });
    return version;
  }

  int restoreEntry(String id, {String? destinationJournalId}) {
    var newVersion = 0;
    _transaction(() {
      final rows = _db.select('SELECT * FROM entries WHERE id = ?', [id]);
      if (rows.isEmpty || rows.single['deleted_at_ms'] == null) {
        throw const JournalUnavailable();
      }
      final old = rows.single;
      final target = destinationJournalId ?? old['journal_id'] as String;
      _requireWritableJournal(target);
      _storeRevision(old);
      _db.execute('''
        UPDATE entries SET journal_id=?, deleted_at_ms=NULL,
          updated_at_ms=?, version=version+1
        WHERE id=? AND version=?
      ''', [
        target, max(_now(), old['updated_at_ms'] as int), id, old['version'],
      ]);
      if (_db.updatedRows != 1) throw const JournalConflict();
      newVersion = (old['version'] as int) + 1;
    });
    return newVersion;
  }

  /// Test-only encrypted media block; no external plaintext thumbnail cache.
  Future<String> attachMedia({
    required String entryId,
    required String filename,
    required String mime,
    required Uint8List bytes,
  }) async {
    if (bytes.length > ProductSnapshotCodec.maxMediaBytes ||
        bytes.isEmpty ||
        filename.isEmpty || filename == '.' || filename == '..' ||
        filename.contains('/') || filename.contains('\\') ||
        filename.runes.any((r) => r < 32 || r == 127) ||
        filename.runes.length > 160 ||
        !RegExp(r'^[a-zA-Z0-9.+_-]+/[a-zA-Z0-9.+_-]+$').hasMatch(mime)) {
      throw ArgumentError('Unsafe media fixture metadata or size');
    }
    final digest = base64Encode((await Sha256().hash(bytes)).bytes);
    final id = _id();
    _transaction(() {
      final entries = _db.select('SELECT journal_id,deleted_at_ms '
          'FROM entries WHERE id=?', [entryId]);
      if (entries.isEmpty || entries.single['deleted_at_ms'] != null) {
        throw const JournalUnavailable();
      }
      _requireWritableJournal(entries.single['journal_id'] as String);
      _db.execute('''
        INSERT INTO attachments(id,entry_id,name,mime,bytes,sha256)
        VALUES(?,?,?,?,?,?)
      ''', [id, entryId, filename, mime, bytes, digest]);
    });
    return id;
  }

  List<Map<String, dynamic>> listRevisions(String entryId) {
    _ensureOpen();
    return _db.select('SELECT * FROM revisions WHERE entry_id=? ORDER BY version',
      [entryId]).map(_revision).toList(growable: false);
  }

  bool integrityCheck() {
    _ensureOpen();
    return _db.select('PRAGMA integrity_check').single.columnAt(0) == 'ok' &&
        _db.select('PRAGMA foreign_key_check').isEmpty;
  }

  static Map<String, dynamic> _journal(Row r) => {
    'id': r['id'] as String,
    'name': r['name'] as String,
    'archived': r['archived'] == 1,
    'createdAtMs': r['created_at_ms'] as int,
    'deletedAtMs': r['deleted_at_ms'] as int?,
  };
  static Map<String, dynamic> _entry(Row r) => {
    'id': r['id'] as String,
    'journalId': r['journal_id'] as String,
    'title': r['title'] as String,
    'body': r['body'] as String,
    'createdAtMs': r['created_at_ms'] as int,
    'updatedAtMs': r['updated_at_ms'] as int,
    'eventAtMs': r['event_at_ms'] as int?,
    'version': r['version'] as int,
    'deletedAtMs': r['deleted_at_ms'] as int?,
  };
  static Map<String, dynamic> _revision(Row r) => {
    'entryId': r['entry_id'] as String,
    'version': r['version'] as int,
    'journalId': r['journal_id'] as String,
    'title': r['title'] as String,
    'body': r['body'] as String,
    'eventAtMs': r['event_at_ms'] as int?,
    'updatedAtMs': r['updated_at_ms'] as int,
  };
  static Map<String, dynamic> _attachment(Row r) => {
    'id': r['id'] as String,
    'entryId': r['entry_id'] as String,
    'name': r['name'] as String,
    'mime': r['mime'] as String,
    'data': base64Encode(r['bytes'] as List<int>),
    'sha256': r['sha256'] as String,
  };

  /// Snapshot from one consistent SQLite transaction (WAL snapshot isolation).
  /// Returns a plaintext IN-MEMORY map; callers MUST NOT write/log it.
  /// onAfterJournals is a test-only race seam for concurrent SQLite writers.
  Map<String, dynamic> snapshot({
    void Function()? onAfterJournals,
  }) {
    _ensureOpen();
    _db.execute('BEGIN');
    try {
      final journals = _db.select('SELECT * FROM journals ORDER BY id')
          .map(_journal).toList(growable: false);
      onAfterJournals?.call();
      final entries = _db.select('SELECT * FROM entries ORDER BY id')
          .map(_entry).toList(growable: false);
      final revisions = _db.select('SELECT * FROM revisions ORDER BY entry_id,version')
          .map(_revision).toList(growable: false);
      final attachments = _db.select('SELECT * FROM attachments ORDER BY id')
          .map(_attachment).toList(growable: false);
      if (!integrityCheck()) throw StateError('Journal store integrity failed');
      _db.execute('COMMIT');
      return {
        'format': ProductSnapshotCodec.format,
        'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'journals': journals,
        'entries': entries,
        'revisions': revisions,
        'attachments': attachments,
      };
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// One database snapshot, then authenticated encryption OUTSIDE SQL lock.
  /// Never writes a plaintext archive. Recovery key MUST be independently kept.
  Future<Uint8List> exportEncrypted({
    required RecoveryKey recoveryKey,
  }) async {
    final captured = snapshot();
    return ProductEncryptedArchiveCodec().export(
      recoveryKey: recoveryKey,
      snapshot: captured,
    );
  }
}
