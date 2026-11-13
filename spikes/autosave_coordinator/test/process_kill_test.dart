/// A3.4 real OS SIGKILL regression checks on Linux, fictional data only.
///
/// Validates SQLite3MultipleCiphers WAL and transaction recovery after *real*
/// child-process termination, not just injected exceptions. NOT Android
/// force-stop or a guarantee that unacknowledged editor keystrokes survive.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_draft_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:test/test.dart';

const _original = DraftContent(
  title: 'Version one — fictional',
  body: 'A3.4_OS_KILL_TEST_ONLY_VERSION_ONE',
);
const _updated = DraftContent(
  title: 'Version two — fictional',
  body: 'A3.4_OS_KILL_TEST_ONLY_VERSION_TWO',
);

void main() {
  if (!Platform.isLinux) return;

  late Directory dir;
  late String file;
  late TestVaultKey key;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('nj_real_sigkill_');
    file = dir.path + Platform.pathSeparator + 'crash-fixture.db';
    key = TestVaultKey.random();
    final db = EncryptedDraftStore.open(file, key: key, create: true);
    try {
      final result = await db.commit(
        entryId: 'fake-entry', expectedVersion: 0, content: _original,
      );
      expect(result.version, 1);
    } finally {
      db.close();
    }
  });

  tearDown(() {
    key.destroy();
    dir.deleteSync(recursive: true);
  });

  /// Pause a separate VM exactly at a chosen storage boundary, then send a
  /// real SIGKILL. An unused/accidentally completed helper must FAIL this test.
  Future<void> killAt(String mode, String expectedMarker) async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/crash_writer.dart', file, mode],
      workingDirectory: Directory.current.path,
    );
    final marker = Completer<void>();
    final output = <String>[];
    final subscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      output.add(line);
      if (line == expectedMarker && !marker.isCompleted) marker.complete();
    });
    final errors = <String>[];
    final errorSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => errors.add(line));
    try {
      process.stdin.writeln(key.hex);
      await process.stdin.flush();
      await process.stdin.close();
      await marker.future.timeout(const Duration(seconds: 55));
      expect(output, contains(expectedMarker));
      expect(process.kill(ProcessSignal.sigkill), isTrue);
      final exit = await process.exitCode.timeout(const Duration(seconds: 15));
      expect(exit, isNot(0), reason: 'A real terminated child must not succeed');
    } finally {
      process.kill(ProcessSignal.sigkill);
      await subscription.cancel();
      await errorSubscription.cancel();
    }
    // No private text/key is printed into error messages.
    expect(errors, isEmpty, reason: 'The isolated crash-writer failed unexpectedly');
  }

  Future<void> verify(int expectedVersion, DraftContent expected,
      {int priorRevisionCount = 0}) async {
    final recovered = EncryptedDraftStore.open(file, key: key);
    try {
      expect(recovered.getVersion('fake-entry'), expectedVersion);
      expect(recovered.read('fake-entry'), expected);
      expect(recovered.history('fake-entry'), hasLength(priorRevisionCount));
      expect(recovered.integrityCheck(), isTrue);
    } finally {
      recovered.close();
    }
  }

  test('real SIGKILL inside SQLite edit transaction rolls back WAL',
      () async {
    await killAt('inside_transaction', 'INSIDE_TRANSACTION');
    await verify(1, _original);
  }, timeout: const Timeout(Duration(seconds: 100)));

  test('real SIGKILL after COMMIT before ack retains committed snapshot',
      () async {
    await killAt('after_commit_before_ack', 'COMMIT_UNACKNOWLEDGED');
    await verify(2, _updated, priorRevisionCount: 1);

    // Controller would have no receipt. Retrying exact original request
    // must return the already-committed version, not duplicate a revision.
    final db = EncryptedDraftStore.open(file, key: key);
    try {
      final receipt = await db.commit(
        entryId: 'fake-entry', expectedVersion: 1, content: _updated,
      );
      expect(receipt.version, 2);
      expect(db.history('fake-entry'), [_original]);
    } finally {
      db.close();
    }
  }, timeout: const Timeout(Duration(seconds: 100)));

  test('real SIGKILL after acknowledgement retains version 2 on reopen',
      () async {
    await killAt('after_ack', 'ACKNOWLEDGED');
    await verify(2, _updated, priorRevisionCount: 1);
  }, timeout: const Timeout(Duration(seconds: 100)));
}
