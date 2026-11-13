import 'dart:convert';
import 'dart:io';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Tests use generated keys and fictional data only.
void main() {
  late Directory temp;
  late String path;
  late TestVaultKey key;
  late EncryptedJournalSpike vault;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('navin_mc_');
    path = temp.path + Platform.pathSeparator + 'fiction.db';
    key = TestVaultKey.random();
    vault = EncryptedJournalSpike.open(path, key: key, create: true);
  });

  tearDown(() {
    vault.close();
    key.destroy();
    temp.deleteSync(recursive: true);
  });

  test('encrypted backend activates and SQLite reports good integrity', () {
    expect(vault.integrityCheck(), isTrue);
    expect(File(path).existsSync(), isTrue);
    expect(File(path).lengthSync(), greaterThan(0));
  });

  test('random key and mixed Telugu, English, emoji survive close/reopen', () {
    const text = 'ఈ రోజు ప్రశాంతం. A perfect test-only evening 🌿 🪷 👨‍👩‍👧';
    vault.insertFictionalEntry(id: 'fiction-01', title: 'జ్ఞాపకం', body: text);
    vault.close();
    final reopened = EncryptedJournalSpike.open(path, key: key);
    expect(reopened.entryBody('fiction-01'), text);
    expect(reopened.entryVersion('fiction-01'), 1);
    expect(reopened.integrityCheck(), isTrue);
    reopened.close();
    vault = EncryptedJournalSpike.open(path, key: key);
  });

  test('a wrong random key cannot read schema or plaintext', () {
    vault.insertFictionalEntry(
      id: 'fiction-02',
      title: 'A fabricated title',
      body: 'A fabricated and secret-looking test sentence.',
    );
    vault.close();
    final wrong = TestVaultKey.random();
    try {
      expect(
        () => EncryptedJournalSpike.open(path, key: wrong),
        throwsA(anyOf(isA<VaultUnlockFailed>(), isA<SqliteException>())),
      );
    } finally {
      wrong.destroy();
    }
    vault = EncryptedJournalSpike.open(path, key: key);
    expect(vault.entryBody('fiction-02'), contains('fabricated'));
  });

  test('no-key SQLite3MC access rejects encrypted database', () {
    vault.insertFictionalEntry(
      id: 'fiction-03',
      title: 'Test-only',
      body: 'STAGE4_TEST_ONLY_NOT_A_REAL_SECRET',
    );
    vault.close();
    final db = sqlite3.open(path);
    try {
      expect(
        () => db.select('SELECT name FROM sqlite_master'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      db.close();
    }
    vault = EncryptedJournalSpike.open(path, key: key);
  });

  test('standard independent Python SQLite cannot read encrypted file', () async {
    vault.insertFictionalEntry(
      id: 'fiction-04',
      title: 'Not private',
      body: 'STAGE4_DEMO_STANDARD_SQLITE_MUST_REJECT',
    );
    vault.close();
    final python = await Process.run('python3', [
      '-c',
      'import sqlite3,sys\n'
          'path=sys.argv[1]\n'
          'try:\n'
          ' db=sqlite3.connect(path)\n'
          ' db.execute("SELECT name FROM sqlite_master").fetchall()\n'
          'except sqlite3.DatabaseError:\n'
          ' sys.exit(0)\n'
          'else:\n'
          ' sys.exit(2)\n',
      path,
    ]);
    expect(python.exitCode, 0, reason: 'Ordinary sqlite3 must fail');
    vault = EncryptedJournalSpike.open(path, key: key);
  });

  test('raw database and WAL files reveal no fictional text/revision', () {
    const sentinel = 'STAGE4_PROBE_NOT_A_DIARY_ABCDEFGHIJKLMNOPQRSTUVWXYZZYXWV';
    final original = List<String>.filled(200, sentinel).join();
    final revised = 'Revised test ' + List<String>.filled(100, sentinel).join();
    vault.insertFictionalEntry(
      id: 'fiction-05',
      title: sentinel,
      body: original,
    );
    vault.editFictionalEntry(
      id: 'fiction-05',
      expectedVersion: 1,
      body: revised,
    );
    expect(vault.previousBodies('fiction-05'), [original]);
    final probe = utf8.encode(sentinel);
    var foundFiles = 0;
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File(path + suffix);
      if (!file.existsSync()) continue;
      foundFiles++;
      final bytes = file.readAsBytesSync();
      var hits = 0;
      for (var i = 0; i <= bytes.length - probe.length; i++) {
        if (bytes[i] != probe[0]) continue;
        var full = true;
        for (var j = 0; j < probe.length; j++) {
          if (bytes[i + j] != probe[j]) {
            full = false;
            break;
          }
        }
        if (full) hits++;
      }
      expect(hits, 0, reason: 'Plaintext sentinel leaked in ' + suffix);
    }
    expect(foundFiles, greaterThanOrEqualTo(1));
    expect(vault.integrityCheck(), isTrue);
  });

  test('revisions stay encrypted and failed edit rolls back atomically', () {
    vault.insertFictionalEntry(
      id: 'fiction-06',
      title: 'Simulated',
      body: 'committed first',
    );
    final broken = EncryptedJournalSpike.open(
      path,
      key: key,
      failureHook: (point) {
        if (point == 'after_revision_before_update') {
          throw StateError('simulated interrupted edit');
        }
      },
    );
    try {
      expect(
        () => broken.editFictionalEntry(
          id: 'fiction-06', expectedVersion: 1, body: 'partial second',
        ),
        throwsStateError,
      );
    } finally {
      broken.close();
    }
    expect(vault.entryBody('fiction-06'), 'committed first');
    expect(vault.entryVersion('fiction-06'), 1);
    expect(vault.previousBodies('fiction-06'), isEmpty);
    vault.editFictionalEntry(
      id: 'fiction-06', expectedVersion: 1, body: 'committed second',
    );
    expect(vault.previousBodies('fiction-06'), ['committed first']);
    expect(vault.entryVersion('fiction-06'), 2);
  });

  test('unknown schema is rejected without resetting encrypted file', () {
    vault.insertFictionalEntry(
      id: 'fiction-07',
      title: 'Test',
      body: 'Keep this entry',
    );
    vault.close();
    final raw = sqlite3.open(path);
    try {
      raw.execute("PRAGMA cipher = 'chacha20'");
      raw.execute("PRAGMA hexkey = '" + key.hex + "'");
      raw.select('SELECT name FROM sqlite_master');
      raw.userVersion = 99;
    } finally {
      raw.close();
    }
    expect(
      () => EncryptedJournalSpike.open(path, key: key),
      throwsStateError,
    );
    final recover = sqlite3.open(path);
    try {
      recover.execute("PRAGMA cipher = 'chacha20'");
      recover.execute("PRAGMA hexkey = '" + key.hex + "'");
      recover.select('SELECT name FROM sqlite_master');
      recover.userVersion = 1;
    } finally {
      recover.close();
    }
    vault = EncryptedJournalSpike.open(path, key: key);
    expect(vault.entryBody('fiction-07'), 'Keep this entry');
  });

  test('create refuses overwrite and opening nonexistent file fails', () {
    expect(
      () => EncryptedJournalSpike.open(path, key: key, create: true),
      throwsStateError,
    );
    final missing = path + '.missing';
    expect(
      () => EncryptedJournalSpike.open(missing, key: key),
      throwsStateError,
    );
    expect(File(missing).existsSync(), isFalse);
  });

  test('destroyed key fails before touching database', () {
    final destroyed = TestVaultKey.random();
    destroyed.destroy();
    expect(
      () => EncryptedJournalSpike.open(path, key: destroyed),
      throwsStateError,
    );
    expect(vault.integrityCheck(), isTrue);
  });

  test('test key redacts its string representation', () {
    final rendered = key.toString();
    expect(rendered, contains('REDACTED'));
    expect(rendered, isNot(contains(key.hex)));
  });
}
