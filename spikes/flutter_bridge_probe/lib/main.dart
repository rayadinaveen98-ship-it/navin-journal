// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
/// TEST-ONLY Flutter shell: real MethodChannel -> AndroidKeyStore and encrypted
/// SQLite roundtrip, on fictional data. No user diary, no production UX.
/// Only build/debug this package in an isolated disposable environment.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'android_key_bridge.dart';
import 'autosave_probe.dart';

const _sampleBody = 'Fictional entry · తెలుగు test · 🪷';

Future<String> runFictionalBridgeExperiment() async {
  final base = await Directory.systemTemp.createTemp('navin_bridge_probe_');
  final filePath = base.path + Platform.pathSeparator + 'fictional.db';
  final native = FlutterAndroidKeyProtector();
  final coordinator = KeyEnvelopeCoordinator(
    envelopeFile: File(base.path + Platform.pathSeparator + 'envelope.json'),
    protector: native,
  );
  try {
    final raw = await coordinator.initialize(databasePath: filePath);
    final material = TestVaultKey.fromBytes(raw);
    raw.fillRange(0, raw.length, 0);
    try {
      final store = EncryptedJournalSpike.open(
        filePath,
        key: material,
        create: true,
      );
      try {
        store.insertFictionalEntry(
          id: 'sample-fiction',
          title: 'Example only',
          body: _sampleBody,
        );
      } finally {
        store.close();
      }
    } finally {
      material.destroy();
    }

    Future<void> verifyReopen() async {
      final bytes = await coordinator.unlock(databasePath: filePath);
      final key = TestVaultKey.fromBytes(bytes);
      bytes.fillRange(0, bytes.length, 0);
      try {
        final store = EncryptedJournalSpike.open(filePath, key: key);
        try {
          if (store.entryBody('sample-fiction') != _sampleBody ||
              !store.integrityCheck()) {
            throw StateError('Encrypted file did not survive key unwrap');
          }
        } finally {
          store.close();
        }
      } finally {
        key.destroy();
      }
    }

    await verifyReopen();
    await coordinator.rotateWrappingKey(databasePath: filePath);
    await verifyReopen();
    await coordinator.finalizeRotation(databasePath: filePath);
    await verifyReopen();
    return 'PASSED: AndroidKeyStore + Flutter bridge + encrypted SQLite reopen '
        '+ wrapping-key rotation (fictional test only)';
  } finally {
    // This is a disposable probe and its keys are intentionally retired.
    // Production vaults must NEVER do this during error handling or uninstall.
    try {
      final envelope = await coordinator.readEnvelope();
      for (final slot in envelope.slots) {
        try {
          await native.retire(slot.alias);
        } catch (_) {
          // Debug cleanup failure does not justify clearing a user's data.
        }
      }
    } catch (_) {
      // An interrupted provision may leave an orphaned *test-only* alias.
    }
    if (await base.exists()) await base.delete(recursive: true);
  }
}

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('This test harness must never run in a release build');
  }
  runApp(const KeyBridgeProbeApp());
}

class KeyBridgeProbeApp extends StatefulWidget {
  const KeyBridgeProbeApp({super.key});

  @override
  State<KeyBridgeProbeApp> createState() => _KeyBridgeProbeAppState();
}

class _KeyBridgeProbeAppState extends State<KeyBridgeProbeApp> {
  bool running = false;
  String status = 'Not yet tested';

  Future<void> run() async {
    if (running) return;
    setState(() {
      running = true;
      status = 'Running fictional encrypted-key roundtrip…';
    });
    try {
      final result = await runFictionalBridgeExperiment();
      if (mounted) setState(() => status = result);
    } catch (_) {
      if (mounted) {
        // Do not display native exception details or raw key material.
        setState(() => status = 'FAILED: see debug-only test report');
      }
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal Keystore Engineering Probe',
      home: Scaffold(
        appBar: AppBar(title: const Text('Stage 4 A2.4 · TEST HARNESS')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 530),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 48),
                  const SizedBox(height: 22),
                  const Text(
                    'No private writing. No real journal. Test fixtures only.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('run-test'),
                    onPressed: running ? null : run,
                    child: const Text('Run fictional encryption roundtrip'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    key: const ValueKey('open-fictional-autosave'),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const FictionalAutosavePage(),
                      ));
                    },
                    child: const Text('Open fictional autosave editor'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    status,
                    key: const ValueKey('result'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
