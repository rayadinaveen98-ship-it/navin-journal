/// Child used by fictional-only Linux SIGKILL tests. Never ship this code.
/// Runs the genuine staged restore and sends SIGKILL to its own PID at a
/// selected checkpoint to simulate an uncatchable process termination.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) exit(70);
  final fixtureFile = File(args[0]);
  final checkpoint = args[1];
  final fixture = jsonDecode(await fixtureFile.readAsString())
      as Map<String, dynamic>;
  final recovery = RecoveryKey.parse(fixture['recoveryKey'] as String);
  final hex = fixture['databaseKeyHex'] as String;
  final keyBytes = Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
  final destinationKey = TestVaultKey.fromBytes(keyBytes);
  final archive = base64Decode(fixture['archiveBase64'] as String);
  try {
    await StagedProductRestorer(
      injectFailure: (hit) {
        if (hit != checkpoint) return;
        // Only the test harness creates this witness. It contains the
        // checkpoint name, never a recovery key, entry or plaintext.
        File(fixtureFile.path + '.witness')
            .writeAsStringSync(hit, flush: true);
        if (!Process.killPid(pid, ProcessSignal.sigkill)) exit(72);
        // This line must not be reached after SIGKILL.
        exit(73);
      },
    ).restoreNew(
      encryptedArchive: archive,
      recoveryKey: recovery,
      destinationKey: destinationKey,
      destination: Directory(fixture['targetDirectory'] as String),
    );
    exit(74); // Fault injection did not trigger.
  } finally {
    recovery.destroy();
    destinationKey.destroy();
    keyBytes.fillRange(0, keyBytes.length, 0);
    archive.fillRange(0, archive.length, 0);
  }
}
