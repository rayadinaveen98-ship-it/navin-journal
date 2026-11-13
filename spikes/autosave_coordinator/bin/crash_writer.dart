/// A3.4: subprocess OS-kill fixture, Linux CI ONLY. All content fictional.
///
/// Test key is supplied via stdin rather than argument string or logs. This
/// does NOT represent a production key-management or crash-recovery solution.
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_draft_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';

void main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run bin/crash_writer.dart <db> <mode>');
    exitCode = 2;
    return;
  }
  final hex = stdin.readLineSync();
  if (hex == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
    exitCode = 2;
    return;
  }
  final bytes = List<int>.generate(
      32, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  final key = TestVaultKey.fromBytes(bytes);
  final mode = args[1];

  // Print only phase boundaries, never journal text, passwords or key bytes.
  void pauseAt(String marker) {
    stdout.writeln(marker);
    stdout.flush();
    sleep(const Duration(minutes: 3));
  }

  final store = EncryptedDraftStore.open(
    args[0],
    key: key,
    failureHook: (checkpoint) {
      if (mode == 'inside_transaction' &&
          checkpoint == 'after_revision_before_update') {
        pauseAt('INSIDE_TRANSACTION');
      }
      if (mode == 'after_commit_before_ack' &&
          checkpoint == 'after_commit_before_ack') {
        pauseAt('COMMIT_UNACKNOWLEDGED');
      }
    },
  );
  try {
    final receipt = await store.commit(
      entryId: 'fake-entry',
      expectedVersion: 1,
      content: const DraftContent(
        title: 'Version two — fictional',
        body: 'A3.4_OS_KILL_TEST_ONLY_VERSION_TWO',
      ),
    );
    if (mode == 'after_ack' && receipt.version == 2) {
      pauseAt('ACKNOWLEDGED');
    }
    stderr.writeln('Did not pause before expected kill');
    exitCode = 3;
  } finally {
    store.close();
    key.destroy();
  }
}
