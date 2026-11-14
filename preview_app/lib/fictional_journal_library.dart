// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK02: fictional-only Library → Reader → Writing Studio integration.
///
/// Reads actual encrypted journal rows through JournalEditorWorker. Scripted
/// entries only. The diagnostic must not be used for real private journals.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';
import 'connected_writing_studio.dart';
import 'fictional_library_index.dart';
import 'recovery_safety_screen.dart';
import 'visuals.dart';

enum _Screen { library, reader, writer, recovery }

class FictionalJournalLibrary extends StatefulWidget {
  final JournalEditorWorker worker;
  final String journalId;
  final String journalName;
  final Directory? recoveryPrivateRoot;
  final Future<RestoreAssessment> Function()? authenticatedAssessment;
  final Future<List<StagingObservation>> Function(Directory)? inventoryLoader;
  const FictionalJournalLibrary({
    super.key,
    required this.worker,
    required this.journalId,
    this.journalName = 'Fictional Pages',
    this.recoveryPrivateRoot,
    this.authenticatedAssessment,
    this.inventoryLoader,
  });

  @override
  State<FictionalJournalLibrary> createState() => _FictionalJournalLibraryState();
}

class _FictionalJournalLibraryState extends State<FictionalJournalLibrary> {
  _Screen _screen = _Screen.library;
  List<Map<String, Object?>> _pages = [];
  Map<String, Object?>? _reading;
  FictionalPageFilter _filter = FictionalPageFilter.all;
  FictionalPageOrder _order = FictionalPageOrder.newest;
  List<Map<String, Object?>> _revisions = [];
  bool _historyLoaded = false;
  bool _historyBusy = false;
  String? _historyError;
  IsolateJournalEditorSession? _editor;
  EditorSaveNotifier? _notifier;
  FictionalWritingPreset? _fixture;
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    // Disposable fictional diagnostic only. A production flow must never
    // abandon unresolved real private changes on app route disposal.
    _editor?.controller.abandonFictionalTestDraft();
    _notifier?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final list = await widget.worker.listEntries(journalId: widget.journalId);
      if (mounted) setState(() { _pages = list; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() =>
        _error = 'Unable to read the encrypted journal.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readPage(String id) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final row = await widget.worker.readEntry(id);
      if (row == null || row['journalId'] != widget.journalId ||
          row['deletedAtMs'] != null) {
        throw StateError('Entry missing or trashed');
      }
      if (mounted) setState(() {
        _reading = row;
        _revisions = [];
        _historyLoaded = false;
        _historyError = null;
        _screen = _Screen.reader;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open this page.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads real encrypted historical rows on demand. The recovered records
  /// are never written to the clipboard, preferences, a search index, or the
  /// current draft. The diagnostic has no destructive restore-version action.
  Future<void> _loadHistory() async {
    final reading = _reading;
    if (reading == null || _historyLoaded || _historyBusy || _busy) return;
    setState(() { _historyBusy = true; _historyError = null; });
    try {
      final entryId = reading['id'] as String;
      final history = await widget.worker.readRevisions(entryId);
      if (history.any((rev) =>
          rev['entryId'] != entryId ||
          rev['journalId'] != widget.journalId ||
          (rev['version'] as int) >= (reading['version'] as int) ||
          (rev['version'] as int) < 1)) {
        throw StateError('Invalid version history');
      }
      history.sort((a, b) =>
        (b['version'] as int).compareTo(a['version'] as int));
      if (mounted && _reading?['id'] == entryId) setState(() {
        _revisions = history;
        _historyLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() =>
        _historyError = 'Earlier versions could not be verified.');
    } finally {
      if (mounted) setState(() => _historyBusy = false);
    }
  }

  FictionalWritingPreset _scriptedText(int currentVersion) {
    if (currentVersion == 0) {
      return const FictionalWritingPreset(
        'A quiet afternoon',
        'First fictional memory. తెలుగు sample · an imagined day. 🌿',
      );
    }
    if (currentVersion == 1) {
      return const FictionalWritingPreset(
        'A quiet afternoon, revisited',
        'Second fictional memory. తెలుగు sample · another imagined day. 🪷',
      );
    }
    final next = (currentVersion + 1).toString();
    return FictionalWritingPreset('Fictional version ' + next,
      'Only imaginary test content. Chapter ' + next + '. తెలుగు.');
  }

  Future<void> _writePage({String? existingEntryId}) async {
    if (_busy || _screen == _Screen.writer) return;
    setState(() { _busy = true; _error = null; });
    try {
      late final EditorSaveNotifier notifier;
      final session = await widget.worker.startSession(
        journalId: widget.journalId,
        existingEntryId: existingEntryId,
        debounce: const Duration(days: 1),
        onIndicator: (state) => notifier.acknowledge(state),
      );
      notifier = EditorSaveNotifier(session.indicator);
      if (!mounted) {
        session.controller.abandonFictionalTestDraft();
        notifier.dispose();
        return;
      }
      setState(() {
        _editor = session;
        _notifier = notifier;
        _fixture = _scriptedText(session.indicator.databaseVersion);
        _screen = _Screen.writer;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Encrypted editor unavailable.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closedEditor() async {
    final old = _notifier;
    _editor = null;
    _notifier = null;
    _fixture = null;
    _reading = null;
    _revisions = [];
    _historyLoaded = false;
    if (!mounted) {
      old?.dispose();
      return;
    }
    setState(() => _screen = _Screen.library);
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    await _refresh();
  }

  Future<void> _backToLibrary() async {
    if (!mounted) return;
    setState(() {
      _screen = _Screen.library;
      _reading = null;
      _revisions = [];
      _historyLoaded = false;
      _historyError = null;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_screen == _Screen.writer && _editor != null &&
        _notifier != null && _fixture != null) {
      return ConnectedWritingStudio(
        key: ValueKey(_editor!.sessionId),
        controller: _editor!.controller,
        saveStatus: _notifier!,
        fixture: _fixture!,
        scriptOnly: true,
        journalName: widget.journalName,
        onClose: () => unawaited(_closedEditor()),
      );
    }
    const c = JournalColors(false);
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: c.action,
          child: Text('APK 02 DIAGNOSTIC · FICTIONAL DATA ONLY',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onAction, letterSpacing: 1,
              fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 48),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (_screen == _Screen.reader || _screen == _Screen.recovery)
                  IconButton(
                    key: const ValueKey('reader-back'),
                    onPressed: _busy ? null : () => unawaited(_backToLibrary()),
                    icon: const Icon(Icons.arrow_back),
                  ),
                const FoldedPageMark(size: 44),
                const SizedBox(width: 11),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.journalName,
                      style: TextStyle(fontSize: 16, color: c.ink,
                        fontWeight: FontWeight.w700)),
                    Text('THE MEMORY ATELIER',
                      style: TextStyle(fontSize: 10, color: c.secondary,
                        letterSpacing: 1.3)),
                  ],
                )),
              ]),
              const SizedBox(height: 25),
              if (_screen == _Screen.reader) _readerView(c)
              else if (_screen == _Screen.recovery && widget.recoveryPrivateRoot != null)
                RecoverySafetyScreen(
                  privateRoot: widget.recoveryPrivateRoot!,
                  authenticatedAssessment: widget.authenticatedAssessment,
                  inventoryLoader: widget.inventoryLoader,
                )
              else _libraryView(c),
            ]),
          )),
        )),
      ])),
    );
  }

  Widget _libraryView(JournalColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Your Pages', style: editorial(c, 38)),
      const SizedBox(height: 8),
      Text('A quiet place to revisit imagined stories.',
        style: TextStyle(color: c.secondary)),
      const SizedBox(height: 20),
      const ScenicArt(variation: 0, height: 152),
      const SizedBox(height: 17),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: c.subtle,
          border: Border.all(color: c.stroke),
          borderRadius: BorderRadius.circular(14)),
        child: Text('Only scripted fictional pages may be saved here. '
          'This real encrypted database is still an engineering test, '
          'not a private diary or verified backup.',
          style: TextStyle(color: c.secondary, height: 1.5, fontSize: 12)),
      ),
      const SizedBox(height: 21),
      FilledButton.icon(
        key: const ValueKey('library-create-fictional'),
        onPressed: _busy ? null : () => unawaited(_writePage()),
        icon: const Icon(Icons.edit_note_outlined),
        label: const Text('Start a fictional page'),
      ),
      if (widget.recoveryPrivateRoot != null) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('library-review-recovery'),
          onPressed: _busy ? null : () => setState(() {
            _screen = _Screen.recovery;
            _error = null;
          }),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('Review restore safety'),
        ),
        const SizedBox(height: 5),
        Text('Read-only scan. No restore or delete actions.',
          style: TextStyle(color: c.secondary, fontSize: 12)),
      ],
      const SizedBox(height: 27),
      Row(children: [
        Expanded(child: Text('Saved pages', style: editorial(c, 25))),
        IconButton(
          key: const ValueKey('library-refresh'),
          tooltip: 'Refresh encrypted pages',
          onPressed: _busy ? null : () => unawaited(_refresh()),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      if (_loaded && _pages.isNotEmpty) ...[
        const SizedBox(height: 11),
        Text('Find an imagined page · preset searches only',
          style: TextStyle(color: c.secondary, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final filter in FictionalPageFilter.values)
            ChoiceChip(
              key: ValueKey('library-filter-' + filter.name),
              label: Text(switch (filter) {
                FictionalPageFilter.all => 'All pages',
                FictionalPageFilter.telugu => 'తెలుగు',
                FictionalPageFilter.afternoon => 'Afternoon',
                FictionalPageFilter.imagined => 'Imagined',
              }),
              selected: _filter == filter,
              onSelected: _busy ? null : (_) =>
                setState(() => _filter = filter),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(
            'Showing ' + FictionalLibraryIndex.visible(
              source: _pages, filter: _filter, order: _order,
            ).length.toString() + ' of ' + _pages.length.toString() +
            ' fictional pages',
            key: const ValueKey('library-filter-count'),
            style: TextStyle(color: c.secondary, fontSize: 12),
          )),
          DropdownButton<FictionalPageOrder>(
            key: const ValueKey('library-sort'),
            value: _order,
            items: const [
              DropdownMenuItem(value: FictionalPageOrder.newest,
                child: Text('Newest')),
              DropdownMenuItem(value: FictionalPageOrder.oldest,
                child: Text('Oldest')),
              DropdownMenuItem(value: FictionalPageOrder.title,
                child: Text('Title A–Z')),
            ],
            onChanged: _busy ? null : (order) {
              if (order != null) setState(() => _order = order);
            },
          ),
        ]),
        if (FictionalLibraryIndex.visible(
          source: _pages, filter: _filter, order: _order,
        ).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No fictional pages match this preset.',
              key: const ValueKey('library-filter-empty'),
              style: TextStyle(color: c.secondary)),
          ),
      ],
      if (_busy && !_loaded) const LinearProgressIndicator(),
      if (_error != null)
        Padding(padding: const EdgeInsets.all(10),
          child: Text(_error!, key: const ValueKey('library-error'),
            style: TextStyle(color: c.clay))),
      if (_loaded && _pages.isEmpty)
        Container(
          key: const ValueKey('library-empty'),
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: c.paper,
            border: Border.all(color: c.stroke),
            borderRadius: BorderRadius.circular(14)),
          child: Text('No saved fictional pages yet. Open Writing Studio, '
            'insert the scripted sample, save, and return here.',
            style: TextStyle(color: c.secondary, height: 1.5)),
        ),
      for (final row in FictionalLibraryIndex.visible(
        source: _pages, filter: _filter, order: _order,
      ))
        Container(
          key: ValueKey('library-saved-' + (row['id'] as String)),
          margin: const EdgeInsets.only(top: 12),
          child: Material(
            color: c.paper,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.stroke),
            ),
            child: ListTile(
            key: ValueKey('library-open-' + (row['id'] as String)),
            onTap: _busy ? null :
              () => unawaited(_readPage(row['id'] as String)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 17, vertical: 10),
            title: Text(row['title'] as String,
              style: editorial(c, 21), maxLines: 2,
              overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(row['body'] as String, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.secondary))),
            trailing: Text('v' + (row['version'] as int).toString(),
              style: TextStyle(color: c.action)),
            ),
          ),
        ),
    ],
  );

  Widget _readerView(JournalColors c) {
    final row = _reading!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('A PAGE TO REVISIT',
        style: TextStyle(color: c.secondary, letterSpacing: 1.5,
          fontWeight: FontWeight.w700, fontSize: 11)),
      const SizedBox(height: 20),
      Text(row['title'] as String,
        key: const ValueKey('reader-title'), style: editorial(c, 36)),
      const SizedBox(height: 21),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(color: c.paper,
          border: Border.all(color: c.stroke),
          borderRadius: BorderRadius.circular(17)),
        child: Text(row['body'] as String,
          key: const ValueKey('reader-body'),
          style: TextStyle(fontFamily: 'serif',
            height: 1.7, fontSize: 19, color: c.ink)),
      ),
      const SizedBox(height: 16),
      Text('Encrypted version ' + (row['version'] as int).toString(),
        key: const ValueKey('reader-version'),
        style: TextStyle(color: c.secondary, fontSize: 12)),
      const SizedBox(height: 20),
      FilledButton.icon(
        key: const ValueKey('reader-edit'),
        onPressed: _busy ? null :
          () => unawaited(_writePage(existingEntryId: row['id'] as String)),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit fictional page'),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        key: const ValueKey('reader-history'),
        onPressed: _historyBusy || _busy || _historyLoaded
          ? null : () => unawaited(_loadHistory()),
        icon: const Icon(Icons.history),
        label: const Text('View earlier versions'),
      ),
      if (_historyBusy) const Padding(
        padding: EdgeInsets.symmetric(vertical: 13),
        child: LinearProgressIndicator(
          key: ValueKey('reader-history-loading')),
      ),
      if (_historyError != null)
        Padding(padding: const EdgeInsets.only(top: 10),
          child: Text(_historyError!,
            key: const ValueKey('reader-history-error'),
            style: TextStyle(color: c.clay))),
      if (_historyLoaded) ...[
        const SizedBox(height: 13),
        Text('Read-only version history · never replaces current page',
          key: const ValueKey('reader-history-safe-note'),
          style: TextStyle(color: c.secondary, fontSize: 12)),
        if (_revisions.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 10),
            child: Text('No earlier versions saved.',
              key: const ValueKey('reader-history-empty'),
              style: TextStyle(color: c.secondary))),
        for (final previous in _revisions)
          Container(
            key: ValueKey('reader-history-version-' +
              (previous['version'] as int).toString()),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.subtle,
              border: Border.all(color: c.stroke),
              borderRadius: BorderRadius.circular(15)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VERSION ' + (previous['version'] as int).toString(),
                  style: TextStyle(color: c.action,
                    letterSpacing: 1.3, fontSize: 11,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(previous['title'] as String,
                  style: editorial(c, 21)),
                const SizedBox(height: 8),
                Text(previous['body'] as String,
                  style: TextStyle(color: c.ink, height: 1.6)),
              ]),
          ),
      ],
      const SizedBox(height: 20),
      Text('This diagnostic accepts only scripted fictional revisions.',
        style: TextStyle(color: c.secondary, fontSize: 12)),
    ]);
  }
}
