// ignore_for_file: deprecated_member_use
/// APK02 real Flutter editor UI → AndroidKeyStore → encrypted journal worker.
///
/// Scripted fictional journal fixtures ONLY; read-only text fields and a
/// hardcoded sample button. Never distribute this engineering harness as an
/// app for private user writing. No production backup/restore gate cleared.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'connected_writing_studio.dart';
import 'visuals.dart';

const _channel = MethodChannel('navin_journal/test_lifecycle_v1');

const _original = FictionalWritingPreset(
  'The quiet hour',
  'Fictional first page. తెలుగు sample. APK02_TEST_V1 🪷',
);
const _updated = FictionalWritingPreset(
  'The quiet hour, revisited',
  'Fictional revised page. తెలుగు sample. APK02_TEST_V2 🌿',
);

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('APK02 connected editor diagnostic cannot run in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Apk02ConnectedTestApp());
}

class _FixtureContext {
  final JournalEditorWorker worker;
  final KeyEnvelopeCoordinator envelope;
  final String databasePath;
  final String phase;
  final String journalId;
  final IsolateJournalEditorSession session;
  final EditorSaveNotifier changes;

  const _FixtureContext({
    required this.worker,
    required this.envelope,
    required this.databasePath,
    required this.phase,
    required this.journalId,
    required this.session,
    required this.changes,
  });
}

class Apk02ConnectedTestApp extends StatefulWidget {
  const Apk02ConnectedTestApp({super.key});

  @override
  State<Apk02ConnectedTestApp> createState() =>
      _Apk02ConnectedTestAppState();
}

class _Apk02ConnectedTestAppState extends State<Apk02ConnectedTestApp> {
  final _editorKey = GlobalKey<ConnectedWritingStudioState>();
  _FixtureContext? _fixture;
  String _status = 'Preparing the encrypted fictional editor…';
  bool _failed = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    final session = _fixture;
    if (session != null) {
      session.session.controller.abandonFictionalTestDraft();
      session.changes.dispose();
      unawaited(session.worker.close());
    }
    super.dispose();
  }

  Future<void> _marker(String marker) async =>
      _channel.invokeMethod<void>('markPhase', {'marker': marker});

  Future<_FixtureContext> _openFixture(String phase) async {
    final root = await _channel.invokeMethod<String>('getPrivateRoot');
    if (root == null || root.trim().isEmpty) {
      throw StateError('App-private root unavailable');
    }
    final dir = Directory(
      root + Platform.pathSeparator + 'nj_apk02_connected_fixture');
    final dbPath = dir.path + Platform.pathSeparator + 'journal.sqlite3';
    final envelopeFile = File(
      dir.path + Platform.pathSeparator + 'device-envelope.json');
    final databaseFile = File(dbPath);
    final create = phase == 'write_v1';
    if (create) {
      if (envelopeFile.existsSync() || databaseFile.existsSync()) {
        throw StateError('Refusing to reinitialize existing encrypted fixture');
      }
      dir.createSync(recursive: true);
    } else if (!envelopeFile.existsSync() || !databaseFile.existsSync()) {
      throw StateError('Existing encrypted vault or key envelope missing');
    }

    final coordinator = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: FlutterAndroidKeyProtector(),
    );
    final rawKey = create
        ? await coordinator.initialize(databasePath: dbPath)
        : await coordinator.unlock(databasePath: dbPath);
    JournalEditorWorker worker;
    try {
      final native = TestVaultKey.fromBytes(rawKey);
      try {
        worker = await JournalEditorWorker.open(dbPath,
          key: native,
          create: create,
        );
      } finally {
        native.destroy();
      }
    } finally {
      rawKey.fillRange(0, rawKey.length, 0);
    }

    try {
      String journalId;
      String? existingEntryId;
      if (create) {
        journalId = await worker.createJournal('Fictional Pages');
        if ((await worker.listEntries()).isNotEmpty) {
          throw StateError('New fictional test vault not empty');
        }
      } else {
        final entries = await worker.listEntries(includeTrash: true);
        if (entries.length != 1 ||
            entries.single['deletedAtMs'] != null ||
            (await worker.integrityCheck()) != true) {
          throw StateError('Unexpected encrypted fixture');
        }
        final entry = entries.single;
        journalId = entry['journalId'] as String;
        existingEntryId = entry['id'] as String;
        if (phase == 'reopen_and_write_v2') {
          if (entry['version'] != 1 ||
              entry['title'] != _original.title ||
              entry['body'] != _original.body ||
              (await worker.historyCount(existingEntryId)) != 0) {
            throw StateError('First version not durably recovered');
          }
        } else if (phase == 'reopen_v2') {
          if (entry['version'] != 2 ||
              entry['title'] != _updated.title ||
              entry['body'] != _updated.body) {
            throw StateError('Second version not durably recovered');
          }
          final history = await worker.readRevisions(existingEntryId);
          if (history.length != 1 ||
              history.single['version'] != 1 ||
              history.single['title'] != _original.title ||
              history.single['body'] != _original.body) {
            throw StateError('Historical revision not preserved');
          }
        } else {
          throw StateError('Unexpected Android phase');
        }
      }

      late final EditorSaveNotifier updates;
      final session = await worker.startSession(
        journalId: journalId,
        existingEntryId: existingEntryId,
        debounce: const Duration(days: 1),
        onIndicator: (state) => updates.acknowledge(state),
      );
      updates = EditorSaveNotifier(session.indicator);
      return _FixtureContext(
        worker: worker,
        envelope: coordinator,
        databasePath: dbPath,
        phase: phase,
        journalId: journalId,
        session: session,
        changes: updates,
      );
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  Future<void> _initialize() async {
    try {
      final phase = await _channel.invokeMethod<String>('getStartPhase');
      if (phase == null ||
          !const {'write_v1', 'reopen_and_write_v2', 'reopen_v2'}
              .contains(phase)) {
        throw StateError('Invalid Android test phase');
      }
      final fixture = await _openFixture(phase);
      if (!mounted) {
        await fixture.worker.close();
        fixture.changes.dispose();
        return;
      }
      setState(() => _fixture = fixture);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _failed) return;
        if (phase == 'reopen_v2') {
          unawaited(_verifyAndMark(fixture, 'RECOVERED_V2'));
        } else {
          final screen = _editorKey.currentState;
          if (screen == null) {
            unawaited(_fail());
            return;
          }
          unawaited(screen.runFictionalSample());
        }
      });
    } catch (_) {
      await _fail();
    }
  }

  Future<void> _onSaveAcknowledged(SaveIndicator state) async {
    final fixture = _fixture;
    if (fixture == null || _reported || _failed) return;
    if (state.phase != SavePhase.saved || !state.mayLeaveSafely) {
      throw StateError('Unacknowledged edit was not durably saved');
    }
    await _verifyAndMark(fixture,
      fixture.phase == 'write_v1' ? 'ACK_V1' : 'ACK_V2');
  }

  Future<void> _verifyAndMark(
    _FixtureContext fixture,
    String expectedMarker,
  ) async {
    if (_reported || _failed) return;
    try {
      // Independent Android Keystore unwrap and a different Dart isolate,
      // while keeping the primary editor isolate alive.
      final bytes = await fixture.envelope.unlock(
        databasePath: fixture.databasePath);
      JournalEditorWorker? verifier;
      try {
        final key = TestVaultKey.fromBytes(bytes);
        try {
          verifier = await JournalEditorWorker.open(
            fixture.databasePath, key: key);
        } finally {
          key.destroy();
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      try {
        final entries = await verifier.listEntries();
        if (entries.length != 1 ||
            !(await verifier.integrityCheck())) {
          throw StateError('Independent encrypted reopen failed');
        }
        final entry = entries.single;
        final expected = expectedMarker == 'ACK_V1' ? _original : _updated;
        final expectedVersion = expectedMarker == 'ACK_V1' ? 1 : 2;
        if (entry['title'] != expected.title ||
            entry['body'] != expected.body ||
            entry['version'] != expectedVersion ||
            entry['journalId'] != fixture.journalId) {
          throw StateError('Committed entry did not survive independent reopen');
        }
        final history = await verifier.readRevisions(entry['id'] as String);
        if (expectedVersion == 1) {
          if (history.isNotEmpty) {
            throw StateError('Unexpected first-version history');
          }
        } else if (history.length != 1 ||
            history.single['version'] != 1 ||
            history.single['title'] != _original.title ||
            history.single['body'] != _original.body) {
          throw StateError('Previous version did not survive reopen');
        }
      } finally {
        await verifier.close();
      }
      await _marker(expectedMarker);
      _reported = true;
      if (mounted) setState(() =>
        _status = 'Verified encrypted ' + expectedMarker);
    } catch (_) {
      await _fail();
      rethrow;
    }
  }

  Future<void> _fail() async {
    if (_failed || _reported) return;
    _failed = true;
    try {
      await _marker('FAILED');
    } catch (_) {
      // ADB marker timeout also fails; do not leak any journal data into logs.
    }
    if (mounted) setState(() =>
      _status = 'Verification failed. No private writing permitted.');
  }

  @override
  Widget build(BuildContext context) {
    const colors = JournalColors(false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: colors.canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: colors.action),
      ),
      home: _fixture == null || _failed
          ? Scaffold(body: SafeArea(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FoldedPageMark(size: 50),
                    const SizedBox(height: 24),
                    Text('APK 02 fictional editor',
                      style: editorial(colors, 29)),
                    const SizedBox(height: 16),
                    Text(_status,
                      key: const ValueKey('connected-native-status'),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text('Debug-only Android Keystore and encrypted '
                      'journal test. Never enter real diary data.',
                      textAlign: TextAlign.center),
                  ],
                ),
              )),
            ))
          : ConnectedWritingStudio(
              key: _editorKey,
              controller: _fixture!.session.controller,
              saveStatus: _fixture!.changes,
              fixture: _fixture!.phase == 'write_v1' ? _original : _updated,
              scriptOnly: true,
              journalName: 'Fictional Pages',
              onAcknowledged: _onSaveAcknowledged,
              onClose: () {
                if (mounted) {
                  setState(() =>
                      _status = 'Debug-only session closed; no private data');
                }
              },
            ),
    );
  }
}
