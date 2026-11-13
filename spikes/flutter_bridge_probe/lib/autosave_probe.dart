/// Stage 4 A3.3 — debug-only fictional writing + autosave lifecycle probe.
///
/// Not the approved Navin Journal UI. No real private content. A page for
/// Flutter TextFields, AndroidKeyStore key wrapping, encrypted SQLite worker,
/// and explicit Android lifecycle flush requests. No OS-kill guarantee.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_isolate_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'android_key_bridge.dart';

class FictionalAutosavePage extends StatefulWidget {
  const FictionalAutosavePage({super.key});

  @override
  FictionalAutosavePageState createState() => FictionalAutosavePageState();
}

class FictionalAutosavePageState extends State<FictionalAutosavePage>
    with WidgetsBindingObserver {
  static const entryId = 'fictional-entry-a3';

  final titleInput = TextEditingController();
  final bodyInput = TextEditingController();

  Directory? _directory;
  File? _dbFile;
  KeyEnvelopeCoordinator? _envelope;
  EncryptedIsolateStore? _worker;
  DraftAutosaveController? _draft;
  SaveIndicator? _indicator;

  bool _ready = false;
  bool _disposed = false;
  String? _setupError;
  int _backgroundFlushes = 0;

  bool get readyForTest => _ready;
  int get backgroundFlushesForTest => _backgroundFlushes;
  SaveIndicator? get saveIndicatorForTest => _indicator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    titleInput.addListener(_onEditorChanged);
    bodyInput.addListener(_onEditorChanged);
    unawaited(_initialize());
  }

  void _onStatus(SaveIndicator status) {
    _indicator = status;
    if (mounted) setState(() {});
  }

  Future<EncryptedIsolateStore> _openWithEnvelope({required bool create}) async {
    final raw = create
        ? await _envelope!.initialize(databasePath: _dbFile!.path)
        : await _envelope!.unlock(databasePath: _dbFile!.path);
    final key = TestVaultKey.fromBytes(raw);
    raw.fillRange(0, raw.length, 0);
    try {
      return await EncryptedIsolateStore.open(
        _dbFile!.path,
        key: key,
        create: create,
      );
    } finally {
      key.destroy();
    }
  }

  Future<void> _initialize() async {
    try {
      _directory = await Directory.systemTemp.createTemp('nj_a3_3_fixture_');
      _dbFile = File(_directory!.path + Platform.pathSeparator + 'fixture.db');
      _envelope = KeyEnvelopeCoordinator(
        envelopeFile: File(
            _directory!.path + Platform.pathSeparator + 'envelope.json'),
        protector: FlutterAndroidKeyProtector(),
      );
      _worker = await _openWithEnvelope(create: true);
      _draft = DraftAutosaveController(
        entryId: entryId,
        storage: _worker!,
        debounce: const Duration(milliseconds: 350),
        onIndicator: _onStatus,
      );
      _indicator = _draft!.indicator;
      if (_disposed) {
        await _cleanup();
        return;
      }
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _setupError = 'Test vault setup failed');
    }
  }

  void _onEditorChanged() {
    final editor = _draft;
    if (editor == null || _disposed) return;
    final composing = bodyInput.value.composing;
    final active = composing.isValid && !composing.isCollapsed;
    if (active && !editor.isComposing) editor.startComposition();
    editor.update(title: titleInput.text, body: bodyInput.text);
    if (!active && editor.isComposing) editor.endComposition();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundFlushes++;
      final editor = _draft;
      if (editor != null) {
        // No OS guarantee that this Future completes before process death.
        unawaited(editor.flush());
      }
    }
  }

  Future<void> forceSaveForTest() async {
    await _draft!.flush();
    _indicator = _draft!.indicator;
    if (mounted) setState(() {});
  }

  /// Reopen same encrypted file from a newly started storage isolate via
  /// the native Android Keystore. Never regenerate a key on failure.
  Future<bool> verifyReopenForTest() async {
    final old = _draft;
    if (old == null || _worker == null) return false;
    await old.flush();
    if (!old.indicator.mayLeaveSafely) return false;
    final snapshot = old.draft;
    await _worker!.close();
    _worker = await _openWithEnvelope(create: false);
    final stored = await _worker!.read(entryId);
    if (stored == null || stored.content != snapshot) return false;
    old.abandonFictionalTestDraft();
    _draft = DraftAutosaveController(
      entryId: entryId,
      storage: _worker!,
      committedVersion: stored.version,
      initial: stored.content,
      debounce: const Duration(milliseconds: 350),
      onIndicator: _onStatus,
    );
    _indicator = _draft!.indicator;
    if (mounted) setState(() {});
    return true;
  }

  Future<StoredDraft?> readPersistedForTest() async =>
      await _worker?.read(entryId);

  Future<void> _cleanup() async {
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      try {
        await worker.close();
      } catch (_) {}
    }
    final envelope = _envelope;
    if (envelope != null) {
      try {
        final record = await envelope.readEnvelope();
        final provider = FlutterAndroidKeyProtector();
        for (final slot in record.slots) {
          try {
            await provider.retire(slot.alias);
          } catch (_) {}
        }
      } catch (_) {}
    }
    final folder = _directory;
    if (folder != null && await folder.exists()) {
      try {
        await folder.delete(recursive: true);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    titleInput.removeListener(_onEditorChanged);
    bodyInput.removeListener(_onEditorChanged);
    titleInput.dispose();
    bodyInput.dispose();
    _draft?.abandonFictionalTestDraft();
    unawaited(_cleanup()); // Test fixtures only; NEVER production vault cleanup.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A3.3 · Fictional autosave test')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: !_ready
                ? Center(
                    child: Text(
                      _setupError ?? 'Opening disposable encrypted test vault…',
                      key: const ValueKey('setup-status'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'TEST FIXTURE ONLY — no real diaries or private notes',
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        key: const ValueKey('fictional-title'),
                        controller: titleInput,
                        decoration: const InputDecoration(
                          labelText: 'Fictional title',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        key: const ValueKey('fictional-body'),
                        controller: bodyInput,
                        decoration: const InputDecoration(
                          labelText: 'Fictional writing · Telugu/English',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 4,
                        maxLines: 9,
                      ),
                      const SizedBox(height: 15),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _indicator?.accessibleLabel ?? 'Opening test vault',
                          key: const ValueKey('save-status'),
                        ),
                      ),
                      Text(
                        'Version ' + (_indicator?.databaseVersion ?? 0).toString()
                        + ' · background flush requests ' +
                            _backgroundFlushes.toString(),
                        key: const ValueKey('commit-count'),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const ValueKey('force-save'),
                        onPressed: () => unawaited(forceSaveForTest()),
                        child: const Text('Flush fictional draft'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const ValueKey('verify-reopen'),
                        onPressed: () async {
                          final success = await verifyReopenForTest();
                          if (mounted && !success) {
                            setState(() {
                              _setupError = 'Reopen did not verify the draft';
                            });
                          }
                        },
                        child: const Text('Verify encrypted database reopen'),
                      ),
                      if (_setupError != null)
                        Text(_setupError!, key: const ValueKey('reopen-error')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
