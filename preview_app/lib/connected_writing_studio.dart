// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings
/// APK02 reusable real editor UI bound to the existing validated autosave
/// controller. Strictly fictional fixtures until Android + recovery gates pass.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';

import 'visuals.dart';

/// Deliberately hardcoded fictional-only sample; the APK02 diagnostic never
/// allows the user to type private material.
class FictionalWritingPreset {
  final String title;
  final String body;
  const FictionalWritingPreset(this.title, this.body);
}

/// The caller wires controller.onIndicator to this notifier before mounting.
/// This avoids polling and never guesses a successful storage acknowledgement.
class EditorSaveNotifier extends ValueNotifier<SaveIndicator> {
  EditorSaveNotifier(super.value);
  void acknowledge(SaveIndicator next) => value = next;
}

/// A full Writing Studio UI that uses DraftAutosaveController, which in the
/// actual Android integration writes through JournalEditorWorker to encrypted
/// journal_core. No separate/local plaintext draft cache.
///
/// scriptOnly is intentionally required. The debug APK must pass true.
/// Keep this restricted until the private-data release gate is signed off.
class ConnectedWritingStudio extends StatefulWidget {
  final DraftAutosaveController controller;
  final ValueListenable<SaveIndicator> saveStatus;
  final FictionalWritingPreset fixture;
  final bool scriptOnly;
  final Future<void> Function(SaveIndicator)? onAcknowledged;
  final VoidCallback? onClose;
  final String journalName;

  const ConnectedWritingStudio({
    super.key,
    required this.controller,
    required this.saveStatus,
    required this.fixture,
    required this.scriptOnly,
    required this.journalName,
    this.onAcknowledged,
    this.onClose,
  });

  @override
  State<ConnectedWritingStudio> createState() => ConnectedWritingStudioState();
}

class ConnectedWritingStudioState extends State<ConnectedWritingStudio>
    with WidgetsBindingObserver {
  late final TextEditingController titleInput;
  late final TextEditingController bodyInput;
  bool _working = false;
  bool _leaving = false;
  String? _localMessage;
  Future<void>? _backgroundSave;

  @override
  void initState() {
    super.initState();
    titleInput = TextEditingController(text: widget.controller.draft.title);
    bodyInput = TextEditingController(text: widget.controller.draft.body);
    titleInput.addListener(_onChange);
    bodyInput.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    titleInput.removeListener(_onChange);
    bodyInput.removeListener(_onChange);
    titleInput.dispose();
    bodyInput.dispose();
    super.dispose();
  }

  void _onChange() {
    if (_leaving) return;
    final controller = widget.controller;
    final a = titleInput.value.composing;
    final b = bodyInput.value.composing;
    final composing = (a.isValid && !a.isCollapsed) ||
        (b.isValid && !b.isCollapsed);
    if (composing && !controller.isComposing) controller.startComposition();
    controller.update(title: titleInput.text, body: bodyInput.text);
    if (!composing && controller.isComposing) controller.endComposition();
  }

  /// Android may emit inactive -> hidden -> paused for a single background
  /// transition. One best-effort request is enough, and failures must be
  /// consumed asynchronously rather than escaping into an unhandled zone.
  /// This never calls onAcknowledged or claims a background flush succeeded.
  Future<void> _saveOnBackground() async {
    try {
      await widget.controller.flush();
    } catch (_) {
      // Only the SaveIndicator can declare a committed revision. Keep the
      // live draft in memory and let an explicit user save report errors.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_leaving) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_backgroundSave != null) return;
      final work = _saveOnBackground();
      _backgroundSave = work;
      unawaited(work.whenComplete(() {
        if (identical(_backgroundSave, work)) _backgroundSave = null;
      }));
    }
  }

  /// Public only for the fully scripted fictional emulator test. Uses the
  /// exact same TextEditingController -> autosave path as the editor screen.
  Future<void> runFictionalSample() async {
    if (!widget.scriptOnly) {
      throw StateError('This diagnostic method is limited to test fixtures');
    }
    if (_working || _leaving) return;
    titleInput.text = widget.fixture.title;
    bodyInput.text = widget.fixture.body;
    await _saveNow();
  }

  Future<void> _saveNow() async {
    if (_working || _leaving) return;
    if (mounted) setState(() {
      _working = true;
      _localMessage = null;
    });
    try {
      await widget.controller.flush();
      final state = widget.controller.indicator;
      if (!state.mayLeaveSafely || state.phase != SavePhase.saved) {
        if (mounted) setState(() {
          _localMessage = state.phase == SavePhase.conflict
              ? 'Another version exists. Resolve the conflict before leaving.'
              : 'Not saved. Your current draft is still open.';
        });
        return;
      }
      await widget.onAcknowledged?.call(state);
    } catch (_) {
      if (mounted) setState(() => _localMessage =
          'Unable to verify this save. Do not leave this editor.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestClose() async {
    if (_working || _leaving) return;
    setState(() => _working = true);
    bool safe = false;
    try {
      safe = await widget.controller.closeSafely();
    } catch (_) {
      safe = false;
    }
    if (!mounted) return;
    if (safe) {
      _leaving = true;
      setState(() => _working = false);
      widget.onClose?.call();
      return;
    }
    setState(() => _working = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your changes are not safely saved'),
        content: Text(widget.controller.isComposing
          ? 'Finish the current keyboard composition before leaving. '
            'The live draft stays open; a background save may contain '
            'only a partial preedit.'
          : 'This page is still open. Check the save status and retry. '
            'A conflict must be reviewed; the editor never silently overwrites it.'),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(_saveNow());
            },
            child: const Text('Retry saving'),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(SaveIndicator value) {
    return switch (value.phase) {
      SavePhase.pristine => 'Nothing to save',
      SavePhase.dirty => 'Changes not yet saved',
      SavePhase.saving => 'Saving changes…',
      SavePhase.saved => 'Saved locally · version ' +
          value.databaseVersion.toString(),
      SavePhase.error => 'Save failed · retry required',
      SavePhase.conflict => 'Edit conflict · review required',
    };
  }

  static IconData _stateIcon(SavePhase value) => switch (value) {
    SavePhase.saved => Icons.check_circle_outline,
    SavePhase.error => Icons.error_outline,
    SavePhase.conflict => Icons.gpp_bad_outlined,
    SavePhase.dirty => Icons.edit_note_outlined,
    SavePhase.saving => Icons.sync,
    SavePhase.pristine => Icons.notes_outlined,
  };

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Column(children: [
            Container(
              color: c.action,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Text(
                widget.scriptOnly
                    ? 'ENGINEERING PREVIEW · FICTIONAL DATA ONLY'
                    : 'JOURNAL EDITOR · PRIVATE-DATA GATE NOT CLEARED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w700,
                  color: c.onAction,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 18, 7),
              child: Row(children: [
                IconButton(
                  key: const ValueKey('connected-back'),
                  tooltip: 'Close Writing Studio safely',
                  onPressed: _working ? null : () => unawaited(_requestClose()),
                  icon: Icon(Icons.arrow_back, color: c.ink),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.journalName, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.ink,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('WRITING STUDIO', style: TextStyle(
                      color: c.secondary, fontSize: 10,
                      letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  ],
                )),
                ValueListenableBuilder<SaveIndicator>(
                  valueListenable: widget.saveStatus,
                  builder: (context, indicator, child) => Semantics(
                    label: indicator.accessibleLabel,
                    child: Icon(_stateIcon(indicator.phase),
                      size: 22, color: indicator.phase == SavePhase.saved
                        ? c.success : indicator.phase == SavePhase.error ||
                            indicator.phase == SavePhase.conflict
                        ? c.clay : c.action),
                  ),
                ),
              ]),
            ),
            Divider(height: 1, color: c.stroke),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
              child: Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 710),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: c.subtle,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: c.stroke),
                      ),
                      child: Text(
                        widget.scriptOnly
                          ? 'This debug build accepts only scripted fictional text. '
                            'No personal writing, backups or production security '
                            'guarantees are available.'
                          : 'Do not use real private content until Android restore '
                            'and key safety are verified.',
                        style: TextStyle(color: c.secondary,
                          fontSize: 12, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text('FRIDAY · 13 NOVEMBER 2026',
                      style: TextStyle(color: c.secondary, fontSize: 11,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 15),
                    TextField(
                      key: const ValueKey('connected-title'),
                      controller: titleInput,
                      readOnly: widget.scriptOnly,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: editorial(c, 33),
                      decoration: InputDecoration(
                        hintText: 'Give this page a title',
                        hintStyle: editorial(c, 29).copyWith(color: c.secondary),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      key: const ValueKey('connected-body'),
                      controller: bodyInput,
                      readOnly: widget.scriptOnly,
                      minLines: 9,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(fontFamily: 'serif',
                        fontSize: 19, height: 1.65, color: c.ink),
                      decoration: InputDecoration(
                        hintText: 'A moment worth keeping…',
                        hintStyle: TextStyle(fontFamily: 'serif',
                          fontSize: 19, color: c.secondary),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<SaveIndicator>(
                      valueListenable: widget.saveStatus,
                      builder: (context, indicator, child) => Container(
                        key: const ValueKey('connected-save-status'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: c.paper,
                          border: Border.all(color: c.stroke),
                        ),
                        child: Row(children: [
                          Icon(_stateIcon(indicator.phase), size: 20,
                            color: indicator.phase == SavePhase.saved
                              ? c.success : c.action),
                          const SizedBox(width: 11),
                          Expanded(child: Semantics(
                            liveRegion: true,
                            child: Text(_stateLabel(indicator),
                              style: TextStyle(color: c.ink,
                                  fontWeight: FontWeight.w600)),
                          )),
                        ]),
                      ),
                    ),
                    if (_localMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(_localMessage!,
                        key: const ValueKey('connected-error'),
                        style: TextStyle(color: c.clay, fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      if (widget.scriptOnly)
                        OutlinedButton.icon(
                          key: const ValueKey('insert-fictional-sample'),
                          onPressed: _working ? null
                            : () => unawaited(runFictionalSample()),
                          icon: const Icon(Icons.auto_stories_outlined),
                          label: const Text('Use fictional sample'),
                        ),
                      FilledButton.icon(
                        key: const ValueKey('connected-save'),
                        onPressed: _working ? null
                          : () => unawaited(_saveNow()),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save and verify'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text('Only a confirmed encrypted transaction can show '
                        '“Saved locally”. An Android process kill can still '
                        'lose unacknowledged typing.',
                      style: TextStyle(color: c.secondary,
                        fontSize: 12, height: 1.5)),
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
