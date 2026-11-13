// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK 02 vertical slice: approved Writing Studio styling -> real
/// AndroidKeyStore -> encrypted whole-journal SQLite on a worker isolate.
///
/// DEBUG ONLY. All saved data is fixed fictional test content. Not an app
/// for real private writing; no production recovery or safe autosave yet.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'visuals.dart';

const diagnostic = MethodChannel('navin_journal/test_lifecycle_v1');
const originalTitle = 'The quiet hour';
const originalBody = 'Fictional first page. తెలుగు sample. APK02_TEST_V1 🪷';
const revisedTitle = 'The quiet hour, revisited';
const revisedBody = 'Fictional revised page. తెలుగు sample. APK02_TEST_V2 🌿';

class ProbeReceipt {
  final int version;
  final int historyCount;
  final bool valid;
  const ProbeReceipt(this.version, this.historyCount, this.valid);
}

/// SQLite3MC is opened and closed wholly in the background isolate.
Future<ProbeReceipt> onStorageIsolate(
  String path, Uint8List keyBytes, String phase,
) => Isolate.run(() {
  final key = TestVaultKey.fromBytes(keyBytes);
  JournalVault? vault;
  try {
    vault = JournalVault.open(path, key: key, create: phase == 'write_v1');
    if (phase == 'write_v1') {
      final journalId = vault.createJournal('Fictional Pages');
      final entryId = vault.createEntry(
        journalId: journalId, title: originalTitle, body: originalBody);
      final saved = vault.readEntry(entryId);
      return ProbeReceipt(1, 0,
        vault.integrityCheck() &&
        saved?['version'] == 1 &&
        saved?['body'] == originalBody &&
        vault.listRevisions(entryId).isEmpty);
    }
    final entries = vault.listEntries();
    final all = vault.snapshot();
    if (entries.length != 1 || (all['journals'] as List).length != 1) {
      return const ProbeReceipt(-1, -1, false);
    }
    final entry = entries.single;
    final id = entry['id'] as String;
    final journalId = entry['journalId'] as String;
    final history = vault.listRevisions(id);
    if (phase == 'reopen_v1') {
      return ProbeReceipt(entry['version'] as int, history.length,
        vault.integrityCheck() && entry['version'] == 1 &&
        entry['title'] == originalTitle && entry['body'] == originalBody &&
        history.isEmpty);
    }
    if (phase == 'reopen_and_write_v2') {
      if (entry['version'] != 1 || entry['title'] != originalTitle ||
          entry['body'] != originalBody || history.isNotEmpty) {
        return const ProbeReceipt(-1, -1, false);
      }
      final version = vault.editEntry(
        id: id,
        expectedVersion: 1,
        journalId: journalId,
        title: revisedTitle,
        body: revisedBody,
        eventAtMs: null,
      );
      final saved = vault.readEntry(id);
      final revisions = vault.listRevisions(id);
      return ProbeReceipt(version, revisions.length,
        vault.integrityCheck() &&
        saved?['version'] == 2 &&
        saved?['body'] == revisedBody &&
        revisions.length == 1 &&
        revisions.single['body'] == originalBody);
    }
    if (phase == 'reopen_v2') {
      return ProbeReceipt(entry['version'] as int, history.length,
        vault.integrityCheck() && entry['version'] == 2 &&
        entry['title'] == revisedTitle && entry['body'] == revisedBody &&
        history.length == 1 && history.single['body'] == originalBody);
    }
    return const ProbeReceipt(-1, -1, false);
  } finally {
    vault?.close();
    key.destroy();
    keyBytes.fillRange(0, keyBytes.length, 0);
  }
});

class FictionalJournalBridgeService {
  const FictionalJournalBridgeService();

  /// MethodChannel is called on the UI isolate; only SQLite work is moved
  /// into a background isolate. Existing vault or missing key is never reset.
  Future<ProbeReceipt> execute(String phase) async {
    if (!const {
      'write_v1', 'reopen_v1', 'reopen_and_write_v2', 'reopen_v2',
    }.contains(phase)) {
      throw StateError('Unknown debug phase');
    }
    final root = await diagnostic.invokeMethod<String>('getPrivateRoot');
    if (root == null || root.isEmpty) {
      throw StateError('Android app-private storage unavailable');
    }
    final dir = Directory(root + Platform.pathSeparator + 'nj_apk02_fixture');
    final dbPath = dir.path + Platform.pathSeparator + 'journal.sqlite3';
    final envelope = File(dir.path + Platform.pathSeparator + 'envelope.json');
    final db = File(dbPath);
    final create = phase == 'write_v1';
    if (create) {
      if (db.existsSync() || envelope.existsSync()) {
        throw StateError('Existing encrypted fixture: refusing to reset');
      }
      dir.createSync(recursive: true);
    } else if (!db.existsSync() || !envelope.existsSync()) {
      throw StateError('Missing key or database; no auto-creation');
    }
    final keyStore = KeyEnvelopeCoordinator(
      envelopeFile: envelope,
      protector: FlutterAndroidKeyProtector(),
    );
    final raw = create
        ? await keyStore.initialize(databasePath: dbPath)
        : await keyStore.unlock(databasePath: dbPath);
    try {
      // The library copies this material when transferring to the new isolate.
      return await onStorageIsolate(
        dbPath, Uint8List.fromList(raw), phase);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }
}

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('APK02 debug fixture cannot execute in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Apk02WritingStudioProbe());
}

class Apk02WritingStudioProbe extends StatefulWidget {
  const Apk02WritingStudioProbe({super.key});

  @override
  State<Apk02WritingStudioProbe> createState() =>
      _Apk02WritingStudioProbeState();
}

class _Apk02WritingStudioProbeState extends State<Apk02WritingStudioProbe> {
  final titleController = TextEditingController(text: originalTitle);
  final bodyController = TextEditingController(text: originalBody);
  final service = const FictionalJournalBridgeService();
  String status = 'Opening Android secure storage…';
  bool verified = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runPhase());
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _runPhase() async {
    try {
      final phase = await diagnostic.invokeMethod<String>('getStartPhase');
      if (phase == null ||
          !const {'write_v1', 'reopen_and_write_v2', 'reopen_v2'}
              .contains(phase)) {
        throw StateError('Unknown Android launch phase');
      }
      if (phase != 'write_v1') {
        titleController.text = revisedTitle;
        bodyController.text = revisedBody;
      }
      if (mounted) setState(() {
        status = 'Testing committed fictional entry…';
      });
      final receipt = await service.execute(phase);
      final expectedVersion = phase == 'write_v1' ? 1 : 2;
      final expectedHistory = phase == 'write_v1' ? 0 : 1;
      if (!receipt.valid || receipt.version != expectedVersion ||
          receipt.historyCount != expectedHistory) {
        throw StateError('Encrypted write verification failed');
      }
      // A new Dart isolate + SQLite connection independently checks the
      // acknowledged version before telling the Android test script success.
      final check = await service.execute(
        phase == 'write_v1' ? 'reopen_v1' : 'reopen_v2');
      if (!check.valid || check.version != expectedVersion ||
          check.historyCount != expectedHistory) {
        throw StateError('Independent reopen failed');
      }
      final marker = switch (phase) {
        'write_v1' => 'ACK_V1',
        'reopen_and_write_v2' => 'ACK_V2',
        _ => 'RECOVERED_V2',
      };
      await diagnostic.invokeMethod<void>('markPhase', {'marker': marker});
      if (mounted) setState(() {
        verified = true;
        status = switch (phase) {
          'write_v1' => 'Encrypted fictional version 1 acknowledged',
          'reopen_and_write_v2' => 'Encrypted version 2 + revision acknowledged',
          _ => 'Version 2 recovered after Android process restart',
        };
      });
    } catch (_) {
      try {
        await diagnostic.invokeMethod<void>('markPhase', {'marker': 'FAILED'});
      } catch (_) {}
      if (mounted) setState(() {
        verified = false;
        status = 'FAILED · Not a verified saved entry';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: c.action),
        scaffoldBackgroundColor: c.canvas,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Container(
              width: double.infinity,
              color: c.action,
              padding: const EdgeInsets.all(10),
              child: const Text(
                'APK 02 ENGINEERING PROBE · FICTIONAL DATA ONLY',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 690),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FoldedPageMark(size: 46),
                    const SizedBox(height: 24),
                    Text('Writing Studio\nEncrypted test', style: editorial(c, 35)),
                    const SizedBox(height: 12),
                    const Text('Android Keystore protects the key. All database '
                        'work runs off the interface thread. These read-only '
                        'fields contain scripted examples, not personal writing.'),
                    const SizedBox(height: 26),
                    TextField(
                      key: const ValueKey('fictional-title'),
                      controller: titleController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fictional title',
                        border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      key: const ValueKey('fictional-body'),
                      controller: bodyController,
                      readOnly: true,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Fictional sample',
                        border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 17),
                    Text(status, key: const ValueKey('encrypted-status'),
                      style: TextStyle(color: verified
                          ? c.success : c.secondary,
                          fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text('Debug-only: no autosave, real archive restore, '
                        'secure production UI or private-data approval.',
                      style: TextStyle(color: c.secondary, fontSize: 12)),
                  ],
                ),
              )),
            )),
          ]),
        ),
      ),
    );
  }
}
