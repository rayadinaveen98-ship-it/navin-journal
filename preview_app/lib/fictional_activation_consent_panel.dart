// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
/// Explicit fictional-only approval gate for an independently verified
/// encrypted candidate. No automatic consent, overwrite or private writing.
library;

import 'package:flutter/material.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';

import 'visuals.dart';

class FictionalActivationConsentPanel extends StatefulWidget {
  final Future<FictionalActivationState> Function() inspect;
  final Future<FictionalActivationReceipt> Function() activateApproved;
  final Future<void> Function()? onActivated;

  const FictionalActivationConsentPanel({
    super.key,
    required this.inspect,
    required this.activateApproved,
    this.onActivated,
  });

  @override
  State<FictionalActivationConsentPanel> createState() =>
      FictionalActivationConsentPanelState();
}

class FictionalActivationConsentPanelState
    extends State<FictionalActivationConsentPanel> {
  static const phrase = 'ACTIVATE FICTIONAL JOURNAL';
  final TextEditingController _phrase = TextEditingController();
  FictionalActivationState? _status;
  FictionalActivationReceipt? _receipt;
  bool _loading = false;
  bool _busy = false;
  bool _understand = false;
  String? _notice;
  Future<void>? _work;

  @visibleForTesting
  Future<void> waitForIdle() async => await _work;

  @override
  void initState() {
    super.initState();
    _phrase.addListener(_changed);
    _work = refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phrase.removeListener(_changed);
    _phrase.clear();
    _phrase.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!mounted || _busy || _loading) return;
    setState(() {
      _loading = true;
      _notice = null;
      _receipt = null;
      _understand = false;
    });
    _phrase.clear();
    try {
      final status = await widget.inspect();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() =>
          _status = FictionalActivationState.unsafeOrInterrupted);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    if (!mounted || _loading || _busy ||
        _status != FictionalActivationState.awaitingExplicitApproval ||
        !_understand || _phrase.text != phrase) return;
    // Approval comes from this exact two-step user gesture only.
    _phrase.clear();
    setState(() {
      _busy = true;
      _understand = false;
      _notice = null;
      _receipt = null;
    });
    try {
      final receipt = await widget.activateApproved();
      if (receipt.privateWritingApproved ||
          receipt.existingVaultReplaced ||
          receipt.deviceRecoveryCertified) {
        throw const FictionalActivationRejected();
      }
      if (mounted) setState(() {
        _receipt = receipt;
        _status = FictionalActivationState.activeFictionalVault;
      });
      await widget.onActivated?.call();
    } catch (_) {
      if (mounted) setState(() {
        _notice = 'Activation could not be confirmed. No data was erased. '
            'The existing or moved encrypted files remain preserved. '
            'Do not retry an interrupted activation automatically.';
        _status = FictionalActivationState.unsafeOrInterrupted;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    final ready = !_busy && !_loading &&
        _status == FictionalActivationState.awaitingExplicitApproval;
    return Column(
      key: const ValueKey('fictional-activation-consent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Protected journal recovery', style: editorial(c, 24)),
        const SizedBox(height: 8),
        Text('A retained encrypted recovery candidate is never activated '
          'automatically. The destination must be completely empty. '
          'Existing journals cannot be replaced, merged or reset.',
          key: const ValueKey('activation-safety-promise'),
          style: TextStyle(color: c.secondary, height: 1.45)),
        const SizedBox(height: 9),
        Text('FICTIONAL DEBUG ONLY · This does not approve private writing '
          'or a production backup.',
          style: TextStyle(color: c.clay, fontWeight: FontWeight.w600,
            fontSize: 12)),
        const SizedBox(height: 13),
        if (_status == FictionalActivationState.awaitingExplicitApproval)
          Text('A complete encrypted candidate is available for review.',
            key: const ValueKey('activation-awaits-approval'),
            style: TextStyle(color: c.ink)),
        if (_status == FictionalActivationState.notPrepared)
          const Text('No protected candidate is prepared yet.',
            key: ValueKey('activation-not-prepared')),
        if (_status == FictionalActivationState.unsafeOrInterrupted)
          Text('Activation unavailable: destination occupied, or '
            'activation state incomplete/uncertain. The app will not '
            'repair or erase either vault automatically.',
            key: const ValueKey('activation-blocked'),
            style: TextStyle(color: c.clay, height: 1.45)),
        if (_status == FictionalActivationState.activeFictionalVault)
          const Text('Encrypted fictional vault is already activated.',
            key: ValueKey('activation-committed')),
        if (_loading || _busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(
              key: ValueKey('activation-progress')),
          ),
        if (ready) ...[
          const SizedBox(height: 10),
          CheckboxListTile(
            key: const ValueKey('activation-acknowledge'),
            value: _understand,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I authorize activation of this fictional '
              'candidate only if the destination has no existing journal.'),
            onChanged: (value) =>
                setState(() => _understand = value ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('activation-confirmation'),
            controller: _phrase,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Type ACTIVATE FICTIONAL JOURNAL',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('activation-approve'),
            onPressed: _understand && _phrase.text == phrase
                ? () => _work = _activate()
                : null,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Activate into empty fictional Library'),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('activation-refresh'),
          onPressed: _loading || _busy ? null : () => _work = refresh(),
          child: const Text('Check recovery state'),
        ),
        if (_receipt != null) ...[
          const SizedBox(height: 9),
          Text('FICTIONAL ACTIVATION VERIFIED',
            key: const ValueKey('activation-verified'),
            style: TextStyle(color: c.success, fontWeight: FontWeight.w700)),
          Text('${_receipt!.journals} notebooks · '
              '${_receipt!.entries} pages · '
              '${_receipt!.revisions} revisions · '
              '${_receipt!.attachments} attachments',
            key: const ValueKey('activation-counts'),
            style: TextStyle(color: c.ink)),
        ],
        if (_notice != null)
          Text(_notice!, key: const ValueKey('activation-notice'),
            style: TextStyle(color: c.clay, height: 1.45)),
      ],
    );
  }
}
