// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK02 fictional-only end-to-end Library / Reader / Editor Android shell.
/// Not a consumer app, private diary, or independently recoverable vault.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'fictional_journal_library.dart';
import 'visuals.dart';

const _diagnostic = MethodChannel('navin_journal/test_lifecycle_v1');

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Fictional-only APK 02 test must never run in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Apk02LibraryDiagnosticApp());
}

class Apk02LibraryDiagnosticApp extends StatefulWidget {
  const Apk02LibraryDiagnosticApp({super.key});

  @override
  State<Apk02LibraryDiagnosticApp> createState() =>
      _Apk02LibraryDiagnosticAppState();
}

class _Apk02LibraryDiagnosticAppState
    extends State<Apk02LibraryDiagnosticApp> {
  JournalEditorWorker? _worker;
  String? _journalId;
  String _status = 'Unlocking fictional encrypted journal…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    JournalEditorWorker? opened;
    try {
      final root = await _diagnostic.invokeMethod<String>('getPrivateRoot');
      if (root == null || root.trim().isEmpty) {
        throw StateError('App private root is unavailable');
      }
      // A separate test-only vault, not shared with other probe APKs.
      final folder = Directory(
        root + Platform.pathSeparator + 'nj_apk02_library_fixture');
      final dbFile = File(
        folder.path + Platform.pathSeparator + 'journal.sqlite3');
      final envelope = File(
        folder.path + Platform.pathSeparator + 'envelope.json');
      if (dbFile.existsSync() != envelope.existsSync()) {
        // An interrupted first install or missing key must never silently
        // regenerate the original vault. Requires explicit recovery later.
        throw StateError('Incomplete vault: refuse automatic reset');
      }
      final create = !dbFile.existsSync();
      if (create) folder.createSync(recursive: true);
      final protector = KeyEnvelopeCoordinator(
        envelopeFile: envelope,
        protector: FlutterAndroidKeyProtector(),
      );
      final bytes = create
        ? await protector.initialize(databasePath: dbFile.path)
        : await protector.unlock(databasePath: dbFile.path);
      try {
        final key = TestVaultKey.fromBytes(bytes);
        try {
          opened = await JournalEditorWorker.open(
            dbFile.path, key: key, create: create);
        } finally {
          key.destroy();
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }

      // No journal names, titles or entry text are mirrored into
      // SharedPreferences or any other plaintext local metadata.
      String active;
      if (create) {
        active = await opened.createJournal('Fictional Pages');
      } else {
        final journals = await opened.listJournals();
        if (journals.length != 1 ||
            journals.single['deletedAtMs'] != null ||
            journals.single['archived'] != false) {
          throw StateError('Unexpected journal selection state');
        }
        active = journals.single['id'] as String;
      }
      if (!(await opened.integrityCheck())) {
        throw StateError('Encrypted database integrity check failed');
      }
      if (!mounted) {
        await opened.close();
        return;
      }
      setState(() { _worker = opened; _journalId = active; });
    } catch (_) {
      if (opened != null) {
        try { await opened.close(); } catch (_) {}
      }
      if (mounted) setState(() {
        _failed = true;
        _status = 'Could not unlock this fictional journal. '
            'No data has been reset. Do not enter personal writing.';
      });
    }
  }

  @override
  void dispose() {
    final worker = _worker;
    _worker = null;
    if (worker != null) unawaited(worker.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = JournalColors(false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Navin Journal · Fictional APK 02',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: colors.canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: colors.action),
      ),
      home: _worker != null && _journalId != null
        ? FictionalJournalLibrary(
            worker: _worker!,
            journalId: _journalId!,
          )
        : Scaffold(body: SafeArea(child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const FoldedPageMark(size: 60),
                  const SizedBox(height: 23),
                  Text('Fictional Journal', style: editorial(colors, 32)),
                  const SizedBox(height: 17),
                  Text(_status, key: const ValueKey('library-unlock-status'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _failed
                      ? colors.clay : colors.secondary, height: 1.5)),
                  if (!_failed) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ]),
              ),
            ),
          ))),
    );
  }
}
