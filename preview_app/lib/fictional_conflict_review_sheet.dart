// ignore_for_file: deprecated_member_use
// Stage 5D.1 fictional-only conflict review. No real diary data or release use.
// A copy receipt is NOT a successful save of the original page.
import 'package:flutter/material.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';

import 'visuals.dart';

class ConflictReviewCopyReceipt {
  final String entryId;
  final bool matchesCurrentDraft;

  const ConflictReviewCopyReceipt({
    required this.entryId,
    required this.matchesCurrentDraft,
  });
}

class FictionalConflictReviewSheet extends StatefulWidget {
  final DraftAutosaveController controller;
  final Map<String, Object?> newestSaved;
  final Future<ConflictReviewCopyReceipt> Function() preserveAsNew;
  final bool previouslyAttempted;
  final VoidCallback onAttempt;
  final ValueChanged<String> onOutcome;

  const FictionalConflictReviewSheet({
    super.key,
    required this.controller,
    required this.newestSaved,
    required this.preserveAsNew,
    required this.previouslyAttempted,
    required this.onAttempt,
    required this.onOutcome,
  });

  @override
  State<FictionalConflictReviewSheet> createState() =>
      _FictionalConflictReviewSheetState();
}

class _FictionalConflictReviewSheetState
    extends State<FictionalConflictReviewSheet> {
  bool _working = false;
  bool _attemptedHere = false;
  String? _outcome;

  bool get _verifiedNewer =>
      widget.newestSaved['version'] is int &&
      (widget.newestSaved['version'] as int) >
          widget.controller.indicator.databaseVersion &&
      widget.newestSaved['title'] is String &&
      widget.newestSaved['body'] is String;

  String? get _disabledReason {
    if (_working) return 'Checking the separate encrypted page…';
    if (widget.previouslyAttempted || _attemptedHere) {
      return 'This copy operation has already been attempted. Review the '
          'encrypted receipt before another action.';
    }
    if (!widget.controller.hasUnresolvedConflict || !_verifiedNewer) {
      return 'A newer saved version could not be verified.';
    }
    if (widget.controller.isComposing) {
      return 'Finish typing before saving a separate page.';
    }
    if (widget.controller.draft.isBlank) {
      return 'A blank draft cannot be preserved.';
    }
    return null;
  }

  Future<void> _preserve() async {
    if (_disabledReason != null) return;
    // The operation is locked BEFORE crossing the async/unknown-ACK boundary.
    // Do not permit a second click to create a replacement for an ambiguous
    // commit, even if the modal is reopened during this editor session.
    setState(() {
      _attemptedHere = true;
      _working = true;
    });
    widget.onAttempt();
    String message;
    try {
      final receipt = await widget.preserveAsNew();
      if (receipt.entryId.isEmpty) {
        throw StateError('Unconfirmed separate-page receipt');
      }
      message = receipt.matchesCurrentDraft
          ? 'A separate encrypted page was verified. The original page '
              'was not changed. Your current editor still has a conflict.'
          : 'Earlier changes were preserved in a separate encrypted page. '
              'Your newest edits are not saved. The original was not changed.';
    } catch (_) {
      // The storage write might have committed even if the reply was lost.
      // Do not claim failure means no copy exists, and never auto-retry.
      message = 'We could not confirm whether the separate page was saved. '
          'Keep this draft open and inspect saved conflict copies before '
          'attempting another operation.';
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _outcome = message;
    });
    widget.onOutcome(message);
  }

  Widget _versionPanel({
    required String heading,
    required String title,
    required String body,
    required JournalColors c,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(heading, style: TextStyle(
              fontWeight: FontWeight.w700, color: c.action, fontSize: 14,
            )),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(
            color: c.ink, fontSize: 19, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: c.ink, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    final width = MediaQuery.sizeOf(context).width;
    final draft = widget.controller.draft;
    final savedPanel = _versionPanel(
      heading: 'Newest saved page · read only',
      title: (widget.newestSaved['title'] as String?) ?? '',
      body: (widget.newestSaved['body'] as String?) ?? '',
      c: c,
    );
    final draftPanel = _versionPanel(
      heading: 'Your unsaved draft · not backed up',
      title: draft.title,
      body: draft.body,
      c: c,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Review conflicting changes',
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      )),
                  ),
                  const SizedBox(height: 10),
                  Text('A newer saved version exists. Your edits in this '
                    'editor are not saved. Neither version will be overwritten.',
                    style: TextStyle(color: c.secondary, height: 1.5)),
                  const SizedBox(height: 20),
                  if (width < 720)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        savedPanel,
                        const SizedBox(height: 12),
                        draftPanel,
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: savedPanel),
                        const SizedBox(width: 14),
                        Expanded(child: draftPanel),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Text('Save as a new page creates a separately encrypted '
                    'page only after storage verification. It never marks '
                    'the original saved or merges either version.',
                    style: TextStyle(color: c.secondary, height: 1.5)),
                  if (_disabledReason != null) ...[
                    const SizedBox(height: 12),
                    Text(_disabledReason!, key: const ValueKey(
                      'conflict-preserve-disabled-reason'),
                      style: TextStyle(color: c.clay)),
                  ],
                  if (_outcome != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(_outcome!,
                        key: const ValueKey('conflict-preserve-outcome'),
                        style: TextStyle(color: c.ink, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        key: const ValueKey('conflict-preserve-new-page'),
                        onPressed: _disabledReason == null ? _preserve : null,
                        child: const Text('Save as a new page'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('conflict-keep-editing'),
                        onPressed: _working
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Keep editing'),
                      ),
                    ],
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
