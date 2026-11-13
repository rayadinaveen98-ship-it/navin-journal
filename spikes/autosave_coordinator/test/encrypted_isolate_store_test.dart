import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_isolate_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String filename;
  late TestVaultKey key;
  EncryptedIsolateStore? worker;
  DraftAutosaveController? editor;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nj_isolate_');
    filename = dir.path + Platform.pathSeparator + 'fictional.db';
    key = TestVaultKey.random();
    worker = null;
    editor = null;
  });

  tearDown(() async {
    editor?.abandonFictionalTestDraft();
    await worker?.close();
    key.destroy();
    dir.deleteSync(recursive: true);
  });

  Future<EncryptedIsolateStore> fresh() async {
    worker = await EncryptedIsolateStore.open(
      filename,
      key: key,
      create: true,
    );
    return worker!;
  }

  test('create, save, read and encrypted reopen on isolated SQLite worker',
      () async {
    final storage = await fresh();
    final receipt = await storage.commit(
      entryId: 'e1',
      expectedVersion: 0,
      content: const DraftContent(
        title: 'నా డైరీ — sample',
        body: 'తెలుగు + English 🪷 test only',
      ),
    );
    expect(receipt.version, 1);
    expect((await storage.read('e1'))?.content.body,
        'తెలుగు + English 🪷 test only');
    expect(await storage.integrityCheck(), isTrue);
    await worker!.close();
    worker = await EncryptedIsolateStore.open(filename, key: key);
    final reread = await worker!.read('e1');
    expect(reread?.version, 1);
    expect(reread?.content.title, 'నా డైరీ — sample');
  });

  test('autosave controller only reports saved after worker receipt', () async {
    final storage = await fresh();
    editor = DraftAutosaveController(
      entryId: 'e1',
      storage: storage,
      debounce: const Duration(milliseconds: 50),
    );
    editor!.update(title: 'Test', body: 'One');
    expect(editor!.indicator.phase, SavePhase.dirty);
    await editor!.flush();
    expect(editor!.indicator.phase, SavePhase.saved);
    expect(editor!.indicator.databaseVersion, 1);
    expect((await storage.read('e1'))?.content.body, 'One');
  });

  test('worker serializes concurrent requests and detects stale writes',
      () async {
    final storage = await fresh();
    await storage.commit(
      entryId: 'e1',
      expectedVersion: 0,
      content: const DraftContent(title: '', body: 'Initial'),
    );
    final first = storage.commit(
      entryId: 'e1',
      expectedVersion: 1,
      content: const DraftContent(title: '', body: 'Second'),
    );
    final stale = storage.commit(
      entryId: 'e1',
      expectedVersion: 1,
      content: const DraftContent(title: '', body: 'Conflicting'),
    );
    expect((await first).version, 2);
    await expectLater(stale, throwsA(isA<DraftConflict>()));
    expect((await storage.read('e1'))?.content.body, 'Second');
  });

  test('worker rejects missing database without creating a plaintext fallback',
      () async {
    await expectLater(
      EncryptedIsolateStore.open(filename, key: key),
      throwsStateError,
    );
    expect(File(filename).existsSync(), isFalse);
  });

  test('wrong key fails closed; correct key preserves committed test data',
      () async {
    final storage = await fresh();
    await storage.commit(
      entryId: 'e1',
      expectedVersion: 0,
      content: const DraftContent(title: 'A', body: 'Only fictional'),
    );
    await worker!.close();
    final wrong = TestVaultKey.random();
    try {
      await expectLater(
        EncryptedIsolateStore.open(filename, key: wrong),
        throwsStateError,
      );
    } finally {
      wrong.destroy();
    }
    worker = await EncryptedIsolateStore.open(filename, key: key);
    expect((await worker!.read('e1'))?.content.body, 'Only fictional');
  });

  test('new untouched editor flush does not invent blank entry', () async {
    final storage = await fresh();
    editor = DraftAutosaveController(entryId: 'e1', storage: storage);
    await editor!.flush();
    expect(await storage.read('e1'), isNull);
    expect(editor!.indicator.phase, SavePhase.pristine);
  });

  test('dedicated worker persists each acknowledged revision across reopen',
      () async {
    final storage = await fresh();
    editor = DraftAutosaveController(
      entryId: 'e1',
      storage: storage,
      debounce: const Duration(milliseconds: 25),
    );
    editor!.update(title: '', body: 'First');
    await editor!.flush();
    editor!.update(title: '', body: 'Second');
    await editor!.flush();
    expect(editor!.indicator.databaseVersion, 2);
    await worker!.close();
    worker = await EncryptedIsolateStore.open(filename, key: key);
    final saved = await worker!.read('e1');
    expect(saved?.content.body, 'Second');
    expect(saved?.version, 2);
  });

  test('worker close rejects subsequent writes, not an invisible save',
      () async {
    final storage = await fresh();
    await storage.close();
    await expectLater(
      storage.commit(
        entryId: 'e1',
        expectedVersion: 0,
        content: const DraftContent(title: '', body: 'Not saved'),
      ),
      throwsStateError,
    );
    worker = null;
  });
}
