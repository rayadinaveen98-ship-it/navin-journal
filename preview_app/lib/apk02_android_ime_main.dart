// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
/// API-34 Android *synthetic* Telugu preedit / real HOME + force-stop harness.
///
/// This fixture keeps both TextFields read-only. It injects fixed imaginary
/// Telugu text by TextEditingValue rather than accepting any private input.
/// Native Gboard composition, physical power-loss and data migration are NOT
/// proved by this diagnostic.
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

const _native = MethodChannel('navin_journal/test_lifecycle_v1');
const _title = 'కల్పితమైన జ్ఞాపకం';
const _partial = 'తెలు';
const _finished = 'తెలుగు కథ 🌿 పూర్తిగా కల్పితం';
const _phases = <String>{
  'ime_prepare', 'ime_finalize', 'ime_reopen',
};

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Fictional IME harness is forbidden in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Apk02AndroidImeDiagnostic());
}

class _Fixture {
  final JournalEditorWorker worker;
  final KeyEnvelopeCoordinator coordinator;
  final String path;
  final String journalId;
  final String phase;
  final IsolateJournalEditorSession? session;
  final EditorSaveNotifier? notifier;

  const _Fixture({
    required this.worker,
    required this.coordinator,
    required this.path,
    required this.journalId,
    required this.phase,
    this.session,
    this.notifier,
  });
}

class Apk02AndroidImeDiagnostic extends StatefulWidget {
  const Apk02AndroidImeDiagnostic({super.key});

  @override
  State<Apk02AndroidImeDiagnostic> createState() =>
      _Apk02AndroidImeDiagnosticState();
}

class _Apk02AndroidImeDiagnosticState extends State<Apk02AndroidImeDiagnostic>
    with WidgetsBindingObserver {
  final _editorKey = GlobalKey<ConnectedWritingStudioState>();
  _Fixture? _fixture;
  bool _ready = false;
  bool _backgroundObserved = false;
  bool _verifying = false;
  bool _reported = false;
  bool _failed = false;
  String _message = 'Opening fictional encrypted fixture…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final f = _fixture;
    f?.session?.controller.abandonFictionalTestDraft();
    f?.notifier?.dispose();
    if (f != null) unawaited(f.worker.close());
    super.dispose();
  }

  Future<void> _mark(String value) =>
      _native.invokeMethod<void>('markPhase', {'marker': value});

  Future<_Fixture> _open(String phase) async {
    final root = await _native.invokeMethod<String>('getPrivateRoot');
    if (root == null || root.isEmpty) {
      throw StateError('Missing app-private root');
    }
    final dir = Directory(
        '$root${Platform.pathSeparator}nj_ime_background_fixture');
    final db = File('${dir.path}${Platform.pathSeparator}journal.sqlite3');
    final envelope = File('${dir.path}${Platform.pathSeparator}envelope.json');
    final create = phase == 'ime_prepare';
    if (create) {
      // Do not reset an already initialized vault, even in this test.
      if (db.existsSync() || envelope.existsSync()) {
        throw StateError('Refuse existing fixture reset');
      }
      dir.createSync(recursive: true);
    } else if (!db.existsSync() || !envelope.existsSync()) {
      throw StateError('Encrypted vault or envelope missing');
    }

    final coordinator = KeyEnvelopeCoordinator(
      envelopeFile: envelope, protector: FlutterAndroidKeyProtector(),
    );
    final raw = create
        ? await coordinator.initialize(databasePath: db.path)
        : await coordinator.unlock(databasePath: db.path);
    late final JournalEditorWorker worker;
    try {
      final key = TestVaultKey.fromBytes(raw);
      try {
        worker = await JournalEditorWorker.open(
          db.path, key: key, create: create);
      } finally {
        key.destroy();
      }
    } finally {
      raw.fillRange(0, raw.length, 0);
    }

    try {
      late final String journalId;
      String? existingId;
      if (create) {
        journalId = await worker.createJournal('Fictional Telugu Notebook');
        if ((await worker.listEntries()).isNotEmpty) {
          throw StateError('New vault is not empty');
        }
      } else {
        final journals = await worker.listJournals();
        final entries = await worker.listEntries(includeTrash: true);
        if (journals.length != 1 || entries.length != 1 ||
            !(await worker.integrityCheck())) {
          throw StateError('Unexpected encrypted fixture state');
        }
        journalId = journals.single['id'] as String;
        existingId = entries.single['id'] as String;
        final e = entries.single;
        if (e['journalId'] != journalId || e['deletedAtMs'] != null ||
            e['title'] != _title ||
            e['body'] != (phase == 'ime_finalize' ? _partial : _finished) ||
            e['version'] != (phase == 'ime_finalize' ? 1 : 2)) {
          throw StateError('Encrypted relaunch data mismatch');
        }
      }
      if (phase == 'ime_reopen') {
        return _Fixture(worker: worker, coordinator: coordinator,
          path: db.path, journalId: journalId, phase: phase);
      }

      late EditorSaveNotifier notifier;
      final session = await worker.startSession(
        journalId: journalId,
        existingEntryId: existingId,
        debounce: const Duration(days: 1),
        onIndicator: (v) => notifier.acknowledge(v),
      );
      notifier = EditorSaveNotifier(session.indicator);
      notifier.addListener(() {
        // Only a committed acknowledgement can trigger a native result.
        if (_ready && _backgroundObserved &&
            notifier.value.phase == SavePhase.saved &&
            notifier.value.mayLeaveSafely) {
          unawaited(_verifyBackground());
        }
      });
      return _Fixture(worker: worker, coordinator: coordinator,
        path: db.path, journalId: journalId, phase: phase,
        session: session, notifier: notifier);
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  Future<void> _initialize() async {
    try {
      final phase = await _native.invokeMethod<String>('getStartPhase');
      if (phase == null || !_phases.contains(phase)) {
        throw StateError('Unexpected test phase');
      }
      final f = await _open(phase);
      if (!mounted) {
        f.notifier?.dispose();
        f.session?.controller.abandonFictionalTestDraft();
        await f.worker.close();
        return;
      }
      setState(() => _fixture = f);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_runPhase(f));
        }
      });
    } catch (_) {
      await _fail();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final f = _fixture;
    if (f?.phase != 'ime_prepare' || !_ready) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundObserved = true;
      unawaited(_verifyBackground());
    }
  }

  Future<void> _runPhase(_Fixture f) async {
    try {
      if (f.phase == 'ime_reopen') {
        await _verifyEncrypted(f, version: 2);
        await _mark('IME_REOPENED_V2');
        _reported = true;
        if (mounted) {
          setState(() => _message =
              'Encrypted fictional Telugu final version recovered');
        }
        return;
      }
      final screen = _editorKey.currentState;
      if (screen == null || f.session == null) {
        throw StateError('Writer screen is not ready');
      }
      if (f.phase == 'ime_prepare') {
        screen.titleInput.value = TextEditingValue(
          text: _title,
          selection: TextSelection.collapsed(offset: _title.length),
        );
        screen.bodyInput.value = TextEditingValue(
          text: _partial,
          selection: TextSelection.collapsed(offset: _partial.length),
          composing: TextRange(start: 0, end: _partial.length),
        );
        if (!f.session!.controller.isComposing ||
            await f.session!.closeSafely() ||
            (await f.worker.listEntries()).isNotEmpty) {
          throw StateError('Premature synthetic preedit save or close');
        }
        _ready = true;
        await _mark('IME_PREEDIT_READY');
      } else {
        // Relaunch verified the encrypted partial v1 and GCM envelope above.
        screen.bodyInput.value = TextEditingValue(
          text: _finished,
          selection: TextSelection.collapsed(offset: _finished.length),
        );
        if (f.session!.controller.isComposing ||
            f.session!.controller.indicator.mayLeaveSafely) {
          throw StateError('Final fictional composition not dirty');
        }
        await f.session!.save();
        if (f.session!.indicator.phase != SavePhase.saved ||
            !f.session!.indicator.mayLeaveSafely ||
            f.session!.indicator.databaseVersion != 2) {
          throw StateError('No acknowledged fictional final version');
        }
        await _verifyEncrypted(f, version: 2);
        await _mark('IME_FINAL_ACK_V2');
        _reported = true;
      }
    } catch (_) {
      await _fail();
    }
  }

  Future<void> _verifyBackground() async {
    final f = _fixture;
    if (f == null || f.phase != 'ime_prepare' || !_ready ||
        !_backgroundObserved || _failed || _reported || _verifying ||
        f.session == null ||
        f.session!.indicator.phase != SavePhase.saved ||
        !f.session!.indicator.mayLeaveSafely) return;
    _verifying = true;
    try {
      // Backgrounding may save a partial preedit, but may not close the writer.
      if (!f.session!.controller.isComposing ||
          await f.session!.closeSafely() ||
          f.session!.indicator.databaseVersion != 1) {
        throw StateError('Preedit dismissed or no durable ACK');
      }
      await _verifyEncrypted(f, version: 1);
      await _mark('IME_BACKGROUND_ACK_V1');
      _reported = true;
    } catch (_) {
      await _fail();
    } finally {
      _verifying = false;
    }
  }

  Future<void> _verifyEncrypted(_Fixture f, {required int version}) async {
    // Separate worker and fresh Keystore unwrap; never report success based
    // solely on the live editor status or on in-memory page contents.
    final raw = await f.coordinator.unlock(databasePath: f.path);
    late final JournalEditorWorker verifier;
    try {
      final key = TestVaultKey.fromBytes(raw);
      try {
        verifier = await JournalEditorWorker.open(f.path, key: key);
      } finally {
        key.destroy();
      }
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
    try {
      final entries = await verifier.listEntries();
      if (entries.length != 1 || !(await verifier.integrityCheck())) {
        throw StateError('Independent encrypted reopen failed');
      }
      final e = entries.single;
      if (e['journalId'] != f.journalId || e['title'] != _title ||
          e['body'] != (version == 1 ? _partial : _finished) ||
          e['version'] != version) {
        throw StateError('Encrypted version mismatch');
      }
      final revs = await verifier.readRevisions(e['id'] as String);
      if (version == 1) {
        if (revs.isNotEmpty) {
          throw StateError('Unexpected historical version');
        }
      } else if (revs.length != 1 || revs.single['version'] != 1 ||
          revs.single['body'] != _partial ||
          revs.single['title'] != _title) {
        throw StateError('Initial fictional Telugu revision missing');
      }
    } finally {
      await verifier.close();
    }
  }

  Future<void> _fail() async {
    if (_reported || _failed) return;
    _failed = true;
    try {
      await _mark('FAILED');
    } catch (_) {
      // Never print source text, keys, paths or native exception details.
    }
    if (mounted) {
      setState(() => _message =
          'Fictional Android lifecycle verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    const colors = JournalColors(false);
    final f = _fixture;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Navin Journal · Fictional IME Safety',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: colors.action),
      ),
      home: f != null && f.phase != 'ime_reopen' && !_failed
          ? ConnectedWritingStudio(
              key: _editorKey,
              controller: f.session!.controller,
              saveStatus: f.notifier!,
              fixture: const FictionalWritingPreset(_title, _finished),
              scriptOnly: true,
              journalName: 'Fictional Telugu Notebook',
            )
          : Scaffold(
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FoldedPageMark(size: 48),
                      const SizedBox(height: 14),
                      Text(_message, textAlign: TextAlign.center),
                      const Text('ENGINEERING TEST · NO PRIVATE WRITING'),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
