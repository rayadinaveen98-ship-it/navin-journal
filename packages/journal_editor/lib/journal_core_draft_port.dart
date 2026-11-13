/// APK 02 editor-to-core integration: FICTIONAL TEST CONTENT ONLY.
///
/// Reuses the existing tested DraftAutosaveController instead of inventing a
/// second debounce/save-state machine. This adapter maps one editor session to
/// a full-schema encrypted JournalVault entry, preserving optimistic versions
/// and previous revisions in the SAME real journal database.
///
/// Synchronous JournalVault operations MUST run inside a background storage
/// isolate in the future Android editor. These tests run on disposable Linux
/// fixture databases. Not for real private writing.
library;

import 'dart:math';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_core/journal_vault.dart';

/// Holds the real persisted ID returned by the encrypted database, while
/// DraftAutosaveController uses a stable logical ID for this editor session.
///
/// First save creates exactly one encrypted entry. Subsequent saves edit the
/// persisted record with compare-and-swap version checks. If an acknowledgement
/// was lost AFTER a durable commit, a retry with matching version+content
/// returns the previous version instead of creating another entry/revision.
///
/// Do not recreate this port for a new blank draft while retrying a lost ACK;
/// recover from the actual persisted journal list before starting a session.
class JournalCoreDraftPort implements DraftCommitPort {
  final JournalVault vault;
  final String journalId;
  final String sessionId;
  final void Function(int committedVersion)? afterCommitBeforeAck;
  final int? eventAtMs;
  String? _storedEntryId;

  JournalCoreDraftPort({
    required this.vault,
    required this.journalId,
    required this.sessionId,
    String? existingEntryId,
    this.eventAtMs,
    this.afterCommitBeforeAck,
  }) : _storedEntryId = existingEntryId {
    if (journalId.isEmpty || sessionId.trim().isEmpty ||
        (existingEntryId != null && existingEntryId.trim().isEmpty)) {
      throw ArgumentError('Editor session and journal IDs required');
    }
  }

  String? get persistedEntryId => _storedEntryId;

  /// An existing record must be loaded from the exact encrypted vault first.
  /// Return the initial content and version for DraftAutosaveController.
  StoredJournalPage? readInitial() {
    final id = _storedEntryId;
    if (id == null) return null;
    final row = vault.readEntry(id);
    if (row == null || row['deletedAtMs'] != null ||
        row['journalId'] != journalId) {
      throw const JournalUnavailable();
    }
    return StoredJournalPage(
      id: id,
      version: row['version'] as int,
      content: DraftContent(
        title: row['title'] as String,
        body: row['body'] as String,
      ),
    );
  }

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    if (entryId != sessionId || expectedVersion < 0) {
      throw const DraftConflict();
    }
    if (content.isBlank) {
      // An existing page can be cleared after user confirmation, but the
      // backend does not permit a record whose title AND body are empty.
      throw StateError('Cannot commit a completely empty journal page');
    }
    final stored = _storedEntryId;
    if (stored == null) {
      if (expectedVersion != 0) throw const DraftConflict();
      final actualId = vault.createEntry(
        journalId: journalId,
        title: content.title,
        body: content.body,
        eventAtMs: eventAtMs,
      );
      // Set immediately after COMMIT: a simulated lost ACK can retry safely.
      _storedEntryId = actualId;
      afterCommitBeforeAck?.call(1);
      return CommitReceipt(sessionId, 1);
    }

    final existing = vault.readEntry(stored);
    if (existing == null || existing['deletedAtMs'] != null ||
        existing['journalId'] != journalId) {
      throw const DraftConflict();
    }
    final version = existing['version'] as int;
    // Editing title/body must not reset a previously assigned event date.
    // An explicit date-edit API will handle changing/clearing it separately.
    final effectiveEventAtMs = eventAtMs ?? existing['eventAtMs'] as int?;
    final matches = existing['title'] == content.title &&
        existing['body'] == content.body &&
        existing['journalId'] == journalId &&
        existing['eventAtMs'] == effectiveEventAtMs;

    // Exact one-version-ahead match is the only acceptable idempotent retry.
    // A different external edit (even the same body at other versions) is a
    // conflict and must never silently overwrite the user's content.
    if (version == expectedVersion + 1 && matches) {
      return CommitReceipt(sessionId, version);
    }
    if (version != expectedVersion) throw const DraftConflict();

    // If the user updated the editor but the final snapshot equals the
    // persisted one, the UI controller should normally notice this first.
    // Returning the same version would be an invalid receipt, so fail closed.
    if (matches) throw StateError('No new persisted revision to acknowledge');

    int next;
    try {
      next = vault.editEntry(
        id: stored,
        expectedVersion: expectedVersion,
        journalId: journalId,
        title: content.title,
        body: content.body,
        eventAtMs: effectiveEventAtMs,
      );
    } on JournalConflict {
      throw const DraftConflict();
    }
    if (next <= expectedVersion) {
      throw StateError('Core did not advance the journal entry version');
    }
    afterCommitBeforeAck?.call(next);
    return CommitReceipt(sessionId, next);
  }
}

class StoredJournalPage {
  final String id;
  final int version;
  final DraftContent content;
  const StoredJournalPage({
    required this.id,
    required this.version,
    required this.content,
  });
}

/// One-use user-facing editor state setup for an already verified vault.
/// This factory does not open a key or database and does not do I/O itself.
class JournalEditorSession {
  final JournalCoreDraftPort port;
  final DraftAutosaveController controller;

  const JournalEditorSession._(this.port, this.controller);

  factory JournalEditorSession.open({
    required JournalCoreDraftPort port,
    Duration debounce = const Duration(milliseconds: 400),
    void Function(SaveIndicator)? onSaveState,
  }) {
    final initial = port.readInitial();
    return JournalEditorSession._(
      port,
      DraftAutosaveController(
        entryId: port.sessionId,
        storage: port,
        initial: initial?.content ?? DraftContent.blank,
        committedVersion: initial?.version ?? 0,
        debounce: debounce,
        onIndicator: onSaveState,
      ),
    );
  }

  String? get persistedEntryId => port.persistedEntryId;
  SaveIndicator get indicator => controller.indicator;
  DraftContent get draft => controller.draft;
  Future<void> save() => controller.flush();
  Future<bool> closeSafely() => controller.closeSafely();
}

/// Session identifiers intentionally carry no content or secrets.
String newEditorSessionId() {
  final random = Random.secure();
  final digits = List<int>.generate(16, (_) => random.nextInt(256));
  return 'edit-' + digits.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}
