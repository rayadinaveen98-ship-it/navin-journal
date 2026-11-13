/// Android emulator integration: Dart -> MethodChannel -> actual AndroidKeyStore
/// -> authenticated envelope -> SQLite3MultipleCiphers -> reopen and rotate.
///
/// TEST FIXTURES ONLY. Do not use private journal contents.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_bridge_probe/main.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real AndroidKeyStore Flutter channel plus encrypted SQLite',
      (tester) async {
    final result = await tester.runAsync(runFictionalBridgeExperiment);
    expect(result, startsWith('PASSED: AndroidKeyStore'));
  });

  testWidgets('unknown native alias fails closed without provisioning',
      (tester) async {
    final provider = FlutterAndroidKeyProtector();
    const nonexistent = 'nj-v1-ffffffffffffffffffffffffffffffff-g99999';
    final outcome = await tester.runAsync(() async {
      try {
        await provider.unwrap(
          nonexistent,
          WrappedSecret(
            List<int>.filled(12, 1),
            List<int>.filled(32, 2),
            List<int>.filled(16, 3),
          ),
          Uint8List.fromList([10, 20]),
        );
        return false;
      } on MissingVaultKey {
        return true;
      }
    });
    expect(outcome, isTrue);
  });
}
