/// STAGE 4 EXPERIMENT — UNENCRYPTED SQLite, FOR FICTIONAL TEST DATA ONLY.
///
/// This is a transaction / revision reference implementation, not an app vault.
/// Do NOT reuse for real private journal entries until encryption and key
/// management are separately reviewed and verified on target devices.
library;

import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

final Random _secureIds = Random.secure();

String _randomId() {
  return List<int>.generate(16, (_) => _secureIds.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

int _utcMillis() => DateTime.now().toUtc().millisecondsSinceEpoch;

class ConflictException implements Exception {
  final String explanation;
  ConflictException(this.explanation);
  @override
  String toString() => 'ConflictException: ' + explanation;
}

class JournalRecord {
  final String id;
  final String name;
  final bool archived;
  final int createdAtMs;
  final int? deletedAtMs;

  const JournalRecord({
    required this.id,
    required this.name,
    required this.archived,
    required this.createdAtMs,
    required this.deletedAtMs,
  });

  factory JournalRecord.fromRow(Row row) => JournalRecord(
        id: row['id'] as String,
        name: row['name'] as String,
        archived: row['archived'] == 1,
        createdAtMs: row['created_at_ms'] as int,
        deletedAtMs: row['deleted_at_ms'] as int?,
      );
}

class EntryRecord {
  final String id;
  final String journalId;
  final String title;
  final String body;
  final int createdAtMs;
  final int updatedAtMs;
  final int? eventAtMs;
  final int version;
  final int? deletedAtMs;

  const EntryRecord({
    required this.id,
    required this.journalId,
    required this.title,
    required this.body,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.eventAtMs,
    required this.version,
    required this.deletedAtMs,
  });

  factory EntryRecord.fromRow(Row row) => EntryRecord(
        id: row['id'] as String,
        journalId: row['journal_id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        createdAtMs: row['created_at_ms'] as int,
        updatedAtMs: row['updated_at_ms'] as int,
        eventAtMs: row['event_at_ms'] as int?,
        version: row['version'] as int,
        deletedAtMs: row['deleted_at_ms'] as int?,
      );
}

class EntryRevision {
  final String entryId;
  final String journalId;
  final String title;
  final String body;
  final int version;
  final int? eventAtMs;

  const EntryRevision({
    required this.entryId,
    required this.journalId,
    required this.title,
    required this.body,
    required this.version,
    required this.eventAtMs,
  });

  factory EntryRevision.fromRow(Row row) => EntryRevision(
        entryId: row['entry_id'] as String,
        journalId: row['journal_id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        version: row['version'] as int,
        eventAtMs: row['event_at_ms'] as int?,
      );
}

/// Reopenable, synchronous SQLite experiment.
///
/// The caller is responsible for the directory and for closing the database.
/// The storage is intentionally UNENCRYPTED. NEVER use it with actual diaries.
class JournalStore {
  final Database _db;

  /// Test-only seam; throwing here simulates failure inside a transaction.
  final void Function(String point)? failureHook;

  JournalStore._(this._db, this.failureHook);

  factory JournalStore.open(String filePath,
      {void Function(String point)? failureHook}) {
    if (filePath.trim().isEmpty) {
      throw ArgumentError.value(filePath, 'filePath', 'Path is required');
    }
    final parent = File(filePath).parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final db = sqlite3.open(filePath);
    try {
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');
      final store = JournalStore._(db, failureHook);
      store._migrate();
      return store;
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  void close() => _db.dispose();

  void _inTransaction(void Function() work) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      work();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _migrate() {
    if (_db.userVersion > 1) {
      throw StateError('Database schema is newer than this experiment');
    }
    if (_db.userVersion == 1) return;

    _inTransaction(() {
      _db.execute('''
        CREATE TABLE journals (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 48),
          archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
          created_at_ms INTEGER NOT NULL,
          deleted_at_ms INTEGER
        ) STRICT
      ''');
      _db.execute('''
        CREATE UNIQUE INDEX unique_active_journal_name
        ON journals (name COLLATE NOCASE)
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
          version INTEGER NOT NULL CHECK (version >= 1),
          deleted_at_ms INTEGER
        ) STRICT
      ''');
      _db.execute('''
        CREATE INDEX entries_journal_visible
        ON entries (journal_id, deleted_at_ms, updated_at_ms DESC)
      ''');
      _db.execute('''
        CREATE TABLE entry_revisions (
          entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE RESTRICT,
          version INTEGER NOT NULL,
          journal_id TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          event_at_ms INTEGER,
          updated_at_ms INTEGER NOT NULL,
          PRIMARY KEY (entry_id, version)
        ) STRICT
      ''');
      _db.userVersion = 1;
    });
  }

  JournalRecord createJournal(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean.runes.length > 48) {
      throw ArgumentError('Journal name must contain 1–48 characters');
    }
    final id = _randomId();
    final now = _utcMillis();
    _inTransaction(() {
      _db.execute(
        'INSERT INTO journals(id, name, archived, created_at_ms) '
        'VALUES (?, ?, 0, ?)',
        [id, clean, now],
      );
    });
    return getJournal(id)!;
  }

  JournalRecord? getJournal(String id) {
    final rows = _db.select('SELECT * FROM journals WHERE id = ?', [id]);
    return rows.isEmpty ? null : JournalRecord.fromRow(rows.first);
  }

  List<JournalRecord> listJournals({
    bool includeArchived = false,
    bool includeDeleted = false,
  }) {
    final rows = _db.select(
      'SELECT * FROM journals WHERE '
      '(? = 1 OR deleted_at_ms IS NULL) AND '
      '(? = 1 OR archived = 0) ORDER BY created_at_ms, id',
      [includeDeleted ? 1 : 0, includeArchived ? 1 : 0],
    );
    return rows.map(JournalRecord.fromRow).toList();
  }

  void renameJournal(String id, String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean.runes.length > 48) {
      throw ArgumentError('Journal name must contain 1–48 characters');
    }
    _inTransaction(() {
      _db.execute(
        'UPDATE journals SET name = ? WHERE id = ? AND deleted_at_ms IS NULL',
        [clean, id],
      );
      if (_db.updatedRows != 1) throw StateError('Journal not found');
    });
  }

  void archiveJournal(String id, {required bool archived}) {
    _inTransaction(() {
      _db.execute(
        'UPDATE journals SET archived = ? '
        'WHERE id = ? AND deleted_at_ms IS NULL',
        [archived ? 1 : 0, id],
      );
      if (_db.updatedRows != 1) throw StateError('Journal not found');
    });
  }

  void trashJournal(String id) {
    _inTransaction(() {
      _db.execute(
        'UPDATE journals SET deleted_at_ms = ? '
        'WHERE id = ? AND deleted_at_ms IS NULL',
        [_utcMillis(), id],
      );
      if (_db.updatedRows != 1) throw StateError('Journal not found');
    });
  }

  void restoreJournal(String id) {
    _inTransaction(() {
      _db.execute(
        'UPDATE journals SET deleted_at_ms = NULL WHERE id = ? '
        'AND deleted_at_ms IS NOT NULL',
        [id],
      );
      if (_db.updatedRows != 1) throw StateError('Deleted journal not found');
    });
  }

  EntryRecord createEntry({
    required String journalId,
    String title = '',
    required String body,
    int? eventAtMs,
  }) {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      throw ArgumentError('Untouched empty entry is not saved');
    }
    final id = _randomId();
    final now = _utcMillis();
    _inTransaction(() {
      _requireVisibleJournal(journalId);
      _db.execute('''
        INSERT INTO entries(
          id, journal_id, title, body, created_at_ms,
          updated_at_ms, event_at_ms, version, deleted_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, NULL)
      ''', [id, journalId, title, body, now, now, eventAtMs]);
    });
    return getEntry(id)!;
  }

  JournalRecord _requireVisibleJournal(String journalId) {
    final journal = getJournal(journalId);
    if (journal == null ||
        journal.deletedAtMs != null ||
        journal.archived) {
      throw StateError('Destination journal unavailable or archived');
    }
    return journal;
  }

  EntryRecord? getEntry(String id) {
    final rows = _db.select('SELECT * FROM entries WHERE id = ?', [id]);
    return rows.isEmpty ? null : EntryRecord.fromRow(rows.first);
  }

  List<EntryRecord> listEntries({
    String? journalId,
    bool includeDeleted = false,
  }) {
    final rows = _db.select(
      'SELECT e.* FROM entries e '
      'JOIN journals j ON j.id = e.journal_id '
      'WHERE (? IS NULL OR e.journal_id = ?) '
      'AND (? = 1 OR e.deleted_at_ms IS NULL) '
      'AND (? = 1 OR j.deleted_at_ms IS NULL) '
      'ORDER BY e.updated_at_ms DESC, e.id',
      [
        journalId,
        journalId,
        includeDeleted ? 1 : 0,
        includeDeleted ? 1 : 0,
      ],
    );
    return rows.map(EntryRecord.fromRow).toList();
  }

  void _savePreviousRevision(EntryRecord before) {
    _db.execute('''
      INSERT INTO entry_revisions (
        entry_id, version, journal_id, title, body, event_at_ms, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      before.id,
      before.version,
      before.journalId,
      before.title,
      before.body,
      before.eventAtMs,
      before.updatedAtMs,
    ]);
  }

  EntryRecord editEntry({
    required String id,
    required int expectedVersion,
    required String journalId,
    required String title,
    required String body,
    required int? eventAtMs,
  }) {
    _inTransaction(() {
      final old = getEntry(id);
      if (old == null || old.deletedAtMs != null) {
        throw StateError('Entry not found or in Trash');
      }
      if (old.version != expectedVersion) {
        throw ConflictException('Another committed revision exists');
      }
      _requireVisibleJournal(journalId);
      if (old.title == title &&
          old.body == body &&
          old.eventAtMs == eventAtMs &&
          old.journalId == journalId) {
        return; // Unchanged content should not manufacture a revision.
      }
      _savePreviousRevision(old);
      failureHook?.call('after_revision_before_update');
      _db.execute(
        'UPDATE entries SET journal_id = ?, title = ?, body = ?, '
        'event_at_ms = ?, updated_at_ms = ?, version = version + 1 '
        'WHERE id = ? AND version = ? AND deleted_at_ms IS NULL',
        [
          journalId,
          title,
          body,
          eventAtMs,
          _utcMillis(),
          id,
          expectedVersion,
        ],
      );
      if (_db.updatedRows != 1) {
        throw ConflictException('Entry changed before this commit');
      }
    });
    return getEntry(id)!;
  }

  List<EntryRevision> listRevisions(String entryId) {
    return _db
        .select(
          'SELECT * FROM entry_revisions WHERE entry_id = ? '
          'ORDER BY version',
          [entryId],
        )
        .map(EntryRevision.fromRow)
        .toList();
  }

  void trashEntry(String id, {required int expectedVersion}) {
    _inTransaction(() {
      final old = getEntry(id);
      if (old == null || old.deletedAtMs != null) {
        throw StateError('Active entry not found');
      }
      if (old.version != expectedVersion) {
        throw ConflictException('Cannot trash stale entry version');
      }
      _savePreviousRevision(old);
      _db.execute(
        'UPDATE entries SET deleted_at_ms = ?, updated_at_ms = ?, '
        'version = version + 1 WHERE id = ? AND version = ?',
        [_utcMillis(), _utcMillis(), id, expectedVersion],
      );
      if (_db.updatedRows != 1) throw ConflictException('Stale entry version');
    });
  }

  void restoreEntry(String id, {String? destinationJournalId}) {
    _inTransaction(() {
      final old = getEntry(id);
      if (old == null || old.deletedAtMs == null) {
        throw StateError('Trashed entry not found');
      }
      final source = getJournal(old.journalId);
      final dest = destinationJournalId ??
          ((source?.deletedAtMs == null && source?.archived == false)
              ? old.journalId
              : null);
      if (dest == null) {
        throw StateError('Select a destination journal before restoring');
      }
      _requireVisibleJournal(dest);
      _savePreviousRevision(old);
      _db.execute(
        'UPDATE entries SET journal_id = ?, deleted_at_ms = NULL, '
        'updated_at_ms = ?, version = version + 1 WHERE id = ? '
        'AND version = ?',
        [dest, _utcMillis(), id, old.version],
      );
      if (_db.updatedRows != 1) throw ConflictException('Stale entry version');
    });
  }

  /// A minimal SQLite consistency signal. NOT proof of backup integrity.
  bool sqliteIntegrityCheck() {
    final rows = _db.select('PRAGMA integrity_check');
    final keyCheck = _db.select('PRAGMA foreign_key_check');
    return rows.length == 1 && rows.first.columnAt(0) == 'ok' && keyCheck.isEmpty;
  }
}
