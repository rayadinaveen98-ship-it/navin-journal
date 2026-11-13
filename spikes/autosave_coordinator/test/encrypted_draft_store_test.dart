import 'dart:convert';
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_draft_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late String filename;
  late TestVaultKey key;
  late EncryptedDraftStore store;
  DraftAutosaveController? editor;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('nj_autosave_encrypted_');
    filename = directory.path + Platform.pathSeparator + 'test.db';
    key = TestVaultKey.random();
    store = EncryptedDraftStore.open(filename, key: key, create: true);
    editor = null;
  });

  tearDown(() {
    editor?.abandonFictionalTestDraft();
    store.close();
    key.destroy();
    directory.deleteSync(recursive: true);
  });

  test('correct key reopens committed Telugu+English+emoji title and body',
      () async {
    editor = DraftAutosaveController(entryId: 'fiction', storage: store);
    const title = 'నా రోజు – fictional journal title';
    const body = 'నా జ్ఞాపకం 🌿 · An imaginary peaceful day. 👨‍👩‍👧';
    editor!.update(title: title, body: body);
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.saved);
    expect(editor!.indicator.databaseVersion, 1);
    store.close();
    store = EncryptedDraftStore.open(filename, key: key);
    expect(store.read('fiction'), const DraftContent(title: title, body: body));
    expect(store.getVersion('fiction'), 1);
    expect(store.integrityCheck(), isTrue);
  });

  test('second edit commits title/body and maintains prior revision', () async {
    editor = DraftAutosaveController(entryId: 'fiction', storage: store);
    editor!.update(title: 'First name', body: 'First body');
    await editor!.flush();
    editor!.update(title: 'Second name', body: 'Second body');
    await editor!.flush();
    expect(store.getVersion('fiction'), 2);
    expect(store.read('fiction'),
        const DraftContent(title: 'Second name', body: 'Second body'));
    expect(store.history('fiction'), [
      const DraftContent(title: 'First name', body: 'First body')
    ]);
    expect(store.integrityCheck(), isTrue);
  });

  test('after-commit lost acknowledgement retries safely on new entry',
      () async {
    store.close();
    var shouldLoseAck = true;
    store = EncryptedDraftStore.open(
      filename,
      key: key,
      failureHook: (point) {
        if (point == 'after_commit_before_ack' && shouldLoseAck) {
          shouldLoseAck = false;
          throw StateError('Simulated lost acknowledgement');
        }
      },
    );
    editor = DraftAutosaveController(entryId: 'fiction', storage: store);
    editor!.update(title: '', body: 'Keep exactly one copy');
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.error);
    expect(editor!.indicator.mayLeaveSafely, isFalse);
    // The SQLite COMMIT happened. Only the ACK was lost.
    expect(store.getVersion('fiction'), 1);
    await editor!.retry();
    expect(editor!.indicator.phase, SavePhase.saved);
    expect(store.getVersion('fiction'), 1);
    expect(store.history('fiction'), isEmpty);
    expect(store.read('fiction')?.body, 'Keep exactly one copy');
  });

  test('lost acknowledgement while updating never duplicates a revision',
      () async {
    await store.commit(
      entryId: 'fiction',
      expectedVersion: 0,
      content: const DraftContent(title: 'Version 1', body: 'Version 1'),
    );
    store.close();
    var first = true;
    store = EncryptedDraftStore.open(
      filename,
      key: key,
      failureHook: (point) {
        if (point == 'after_commit_before_ack' && first) {
          first = false;
          throw StateError('Lost ACK after update');
        }
      },
    );
    editor = DraftAutosaveController(
      entryId: 'fiction',
      storage: store,
      initial: const DraftContent(title: 'Version 1', body: 'Version 1'),
      committedVersion: 1,
    );
    editor!.update(title: 'Version 2', body: 'Version 2');
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.error);
    expect(store.getVersion('fiction'), 2);
    expect(store.history('fiction'), hasLength(1));
    await editor!.retry();
    expect(editor!.indicator.phase, SavePhase.saved);
    expect(store.getVersion('fiction'), 2);
    expect(store.history('fiction'), hasLength(1));
  });

  test('fault between revision and update rolls back atomically', () async {
    await store.commit(
      entryId: 'fiction',
      expectedVersion: 0,
      content: const DraftContent(title: 'Safe', body: 'committed'),
    );
    store.close();
    store = EncryptedDraftStore.open(
      filename,
      key: key,
      failureHook: (point) {
        if (point == 'after_revision_before_update') {
          throw StateError('Simulated interrupted edit');
        }
      },
    );
    editor = DraftAutosaveController(
      entryId: 'fiction',
      storage: store,
      initial: const DraftContent(title: 'Safe', body: 'committed'),
      committedVersion: 1,
    );
    editor!.update(title: 'Incomplete', body: 'Not committed');
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.error);
    expect(store.getVersion('fiction'), 1);
    expect(store.read('fiction')?.body, 'committed');
    expect(store.history('fiction'), isEmpty);
    expect(store.integrityCheck(), isTrue);
  });

  test('two connections reject stale revision; keep external content',
      () async {
    final initial = const DraftContent(title: 'First', body: 'Initial');
    await store.commit(
        entryId: 'fiction', expectedVersion: 0, content: initial);
    final external = EncryptedDraftStore.open(filename, key: key);
    try {
      editor = DraftAutosaveController(
        entryId: 'fiction',
        storage: store,
        initial: initial,
        committedVersion: 1,
      );
      await external.commit(
        entryId: 'fiction',
        expectedVersion: 1,
        content: const DraftContent(title: 'Remote edit', body: 'Keep'),
      );
      editor!.update(title: 'Conflicting', body: 'Do not overwrite');
      await editor!.flush();
      expect(editor!.indicator.phase, SavePhase.conflict);
      expect(store.read('fiction')?.body, 'Keep');
      expect(store.getVersion('fiction'), 2);
    } finally {
      external.close();
    }
  });

  test('wrong key is rejected before changing existing encrypted data',
      () async {
    await store.commit(
        entryId: 'fiction',
        expectedVersion: 0,
        content: const DraftContent(title: '', body: 'Fictional'));
    store.close();
    final wrong = TestVaultKey.random();
    try {
      expect(
        () => EncryptedDraftStore.open(filename, key: wrong),
        throwsA(isA<VaultUnlockFailed>()),
      );
    } finally {
      wrong.destroy();
    }
    store = EncryptedDraftStore.open(filename, key: key);
    expect(store.read('fiction')?.body, 'Fictional');
  });

  test('raw database and WAL do not contain fictional sentinel', () async {
    const sentinel = 'TEST_ONLY_SENSITIVE_SENTINEL_NEVER_REAL_USER_DIARY';
    final longText = List.filled(60, sentinel).join('|');
    await store.commit(
      entryId: 'fiction',
      expectedVersion: 0,
      content: DraftContent(title: sentinel, body: longText),
    );
    await store.commit(
      entryId: 'fiction',
      expectedVersion: 1,
      content: DraftContent(title: 'Revised', body: longText + ' revised'),
    );
    final probe = utf8.encode(sentinel);
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File(filename + suffix);
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      expect(
        _contains(bytes, probe),
        isFalse,
        reason: 'Test-only plaintext sentinel appeared in ' + suffix,
      );
    }
    expect(store.integrityCheck(), isTrue);
  });

  test('future schema is rejected without destroying encrypted journal', () async {
    await store.commit(
      entryId: 'fiction',
      expectedVersion: 0,
      content: const DraftContent(title: 'A', body: 'B'),
    );
    store.close();
    final newer = sqlite3.open(filename);
    try {
      newer.execute("PRAGMA cipher = 'chacha20'");
      newer.execute("PRAGMA hexkey = '${key.hex}'");
      newer.select('SELECT name FROM sqlite_master');
      newer.userVersion = 99;
    } finally {
      newer.close();
    }
    expect(
      () => EncryptedDraftStore.open(filename, key: key),
      throwsStateError,
    );
    final restore = sqlite3.open(filename);
    try {
      restore.execute("PRAGMA cipher = 'chacha20'");
      restore.execute("PRAGMA hexkey = '${key.hex}'");
      restore.select('SELECT name FROM sqlite_master');
      restore.userVersion = 1;
    } finally {
      restore.close();
    }
    store = EncryptedDraftStore.open(filename, key: key);
    expect(store.read('fiction')?.body, 'B');
  });

  test('new blank entry is rejected by encrypted persistence', () async {
    await expectLater(
      store.commit(
        entryId: 'fiction',
        expectedVersion: 0,
        content: DraftContent.blank,
      ),
      throwsStateError,
    );
    expect(store.getVersion('fiction'), isNull);
  });

  test('changed content after lost ACK must not overwrite unknown revision',
      () async {
    store.close();
    var first = true;
    store = EncryptedDraftStore.open(
      filename,
      key: key,
      failureHook: (checkpoint) {
        if (checkpoint == 'after_commit_before_ack' && first) {
          first = false;
          throw StateError('Lost first save acknowledgement');
        }
      },
    );
    editor = DraftAutosaveController(entryId: 'fiction', storage: store);
    editor!.update(title: '', body: 'Initial committed snapshot');
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.error);
    editor!.update(title: '', body: 'Newer unsaved local snapshot');
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.conflict);
    expect(store.read('fiction')?.body, 'Initial committed snapshot');
    expect(store.getVersion('fiction'), 1);
  });

  test('same write after lost ACK is idempotent, different content conflicts',
      () async {
    const sample = DraftContent(title: 'Safe', body: 'Test');
    final first = await store.commit(
        entryId: 'fiction', expectedVersion: 0, content: sample);
    final repeated = await store.commit(
        entryId: 'fiction', expectedVersion: 0, content: sample);
    expect(first.version, 1);
    expect(repeated.version, 1);
    await expectLater(
      store.commit(
        entryId: 'fiction',
        expectedVersion: 0,
        content: const DraftContent(title: 'Different', body: 'Test'),
      ),
      throwsA(isA<DraftConflict>()),
    );
    expect(store.history('fiction'), isEmpty);
  });
}

bool _contains(List<int> bytes, List<int> needle) {
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var same = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        same = false;
        break;
      }
    }
    if (same) return true;
  }
  return false;
}
