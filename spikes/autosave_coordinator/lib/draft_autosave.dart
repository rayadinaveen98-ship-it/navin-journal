/// Stage 4 A3.1 — isolated autosave state-machine experiment.
///
/// Fictional text ONLY. Not a real journal, not a durable database, not an
/// encrypted vault, and not proof of process-kill or device crash recovery.
/// The only authority to say "saved" is an acknowledged storage transaction.
library;

import 'dart:async';

enum SavePhase { pristine, dirty, saving, saved, error, conflict }

class DraftContent {
  final String title;
  final String body;
  const DraftContent({required this.title, required this.body});

  static const blank = DraftContent(title: '', body: '');

  bool get isBlank => title.trim().isEmpty && body.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DraftContent && title == other.title && body == other.body;

  @override
  int get hashCode => Object.hash(title, body);
}

class CommitReceipt {
  final String entryId;
  final int version;
  const CommitReceipt(this.entryId, this.version);
}

class DraftConflict implements Exception {
  const DraftConflict();
  @override
  String toString() => 'DraftConflict';
}

/// Production implementation must only resolve AFTER a committed disk write.
/// Prefer a dedicated storage isolate; do not block the Flutter UI thread.
///
/// Version 0 means no record yet. For subsequent writes, [expectedVersion]
/// is the version read after the last acknowledged commit. A conflict must
/// never trigger an automatic "last write wins" overwrite.
abstract interface class DraftCommitPort {
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  });
}

class SaveIndicator {
  final SavePhase phase;
  final int localRevision;
  final int acknowledgedRevision;
  final int databaseVersion;

  const SaveIndicator({
    required this.phase,
    required this.localRevision,
    required this.acknowledgedRevision,
    required this.databaseVersion,
  });

  bool get hasUnsavedChanges => localRevision > acknowledgedRevision;
  bool get mayLeaveSafely =>
      !hasUnsavedChanges &&
      (phase == SavePhase.saved || phase == SavePhase.pristine);

  /// No title/body, errors, keys or stack traces appear in this model.
  String get accessibleLabel {
    switch (phase) {
      case SavePhase.pristine:
        return 'Nothing to save';
      case SavePhase.dirty:
        return 'Changes not yet saved';
      case SavePhase.saving:
        return 'Saving changes';
      case SavePhase.saved:
        return 'Saved locally';
      case SavePhase.error:
        return 'Save failed. Retry required';
      case SavePhase.conflict:
        return 'Edit conflict. Review before saving';
    }
  }
}

/// One active entry/editor at a time. This is deliberately independent of
/// Flutter widgets, filesystems, SQLite, and device lifecycle event streams.
class DraftAutosaveController {
  final String entryId;
  final DraftCommitPort storage;
  final Duration debounce;
  final void Function(SaveIndicator indicator)? onIndicator;

  DraftContent _content;
  DraftContent _committed;
  int _version;
  int _revision = 0;
  int _acknowledged = 0;
  SavePhase _phase;
  bool _composing = false;
  bool _closed = false;
  Timer? _timer;
  Future<void>? _activeFlush;

  DraftAutosaveController({
    required this.entryId,
    required this.storage,
    DraftContent initial = DraftContent.blank,
    int committedVersion = 0,
    this.debounce = const Duration(milliseconds: 400),
    this.onIndicator,
  })  : _content = initial,
        _committed = initial,
        _version = committedVersion,
        _phase = committedVersion > 0 ? SavePhase.saved : SavePhase.pristine {
    if (entryId.trim().isEmpty) {
      throw ArgumentError('Entry ID is required');
    }
    if (committedVersion < 0) {
      throw ArgumentError('Cannot start with a negative persisted version');
    }
    if (committedVersion == 0 && !initial.isBlank) {
      throw ArgumentError('New entry must start as an untouched blank draft');
    }
    if (debounce.isNegative) {
      throw ArgumentError('Debounce interval cannot be negative');
    }
  }

  DraftContent get draft => _content;
  SaveIndicator get indicator => SaveIndicator(
        phase: _phase,
        localRevision: _revision,
        acknowledgedRevision: _acknowledged,
        databaseVersion: _version,
      );

  bool get isComposing => _composing;

  void _publish(SavePhase next) {
    _phase = next;
    onIndicator?.call(indicator);
  }

  /// Call on each editor change; IME composition must use start/end methods.
  void update({required String title, required String body}) {
    if (_closed) throw StateError('Draft controller is closed');
    final next = DraftContent(title: title, body: body);
    if (next == _content) return;
    _content = next;
    _revision++;
    _timer?.cancel();
    _timer = null;

    // Returning exactly to acknowledged content while idle is not dirty.
    if (_content == _committed && _activeFlush == null) {
      _acknowledged = _revision;
      _publish(_version > 0 ? SavePhase.saved : SavePhase.pristine);
      return;
    }

    _publish(SavePhase.dirty);
    if (!_composing) _schedule();
  }

  void startComposition() {
    if (_closed) throw StateError('Draft controller is closed');
    _composing = true;
    _timer?.cancel();
    _timer = null;
  }

  void endComposition() {
    if (_closed) throw StateError('Draft controller is closed');
    _composing = false;
    if (indicator.hasUnsavedChanges) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Forced save for editor pause/background or explicit user action.
  ///
  /// Force-flush is allowed during IME composition because losing a draft on
  /// lifecycle exit is worse than retaining a partial composition snapshot;
  /// callers must still preserve the live editor buffer in memory.
  Future<void> flush() {
    if (_closed) throw StateError('Draft controller is closed');
    _timer?.cancel();
    _timer = null;
    final active = _activeFlush;
    if (active != null) return active;
    final work = _drain();
    _activeFlush = work;
    return work.whenComplete(() {
      if (identical(_activeFlush, work)) _activeFlush = null;
    });
  }

  Future<void> _drain() async {
    while (!_closed) {
      if (_content == _committed) {
        _acknowledged = _revision;
        _publish(_version > 0 ? SavePhase.saved : SavePhase.pristine);
        return;
      }
      if (_version == 0 && _content.isBlank) {
        _committed = _content;
        _acknowledged = _revision;
        _publish(SavePhase.pristine);
        return;
      }
      final snapshot = _content;
      final sequence = _revision;
      final expected = _version;
      _publish(SavePhase.saving);
      try {
        final receipt = await storage.commit(
          entryId: entryId,
          expectedVersion: expected,
          content: snapshot,
        );
        if (receipt.entryId != entryId || receipt.version <= expected) {
          throw StateError('Storage commit returned an invalid receipt');
        }
        _version = receipt.version;
        _committed = snapshot;
        _acknowledged = sequence;
      } on DraftConflict {
        _publish(SavePhase.conflict);
        return;
      } catch (_) {
        // Never log the private draft or a raw native exception.
        _publish(SavePhase.error);
        return;
      }

      if (_content == snapshot) {
        _acknowledged = _revision;
        _publish(SavePhase.saved);
        return;
      }
      // A newer edit arrived while the previous save was in flight.
      // The old acknowledgement NEVER marks the newer draft as saved.
      _publish(SavePhase.dirty);
    }
  }

  /// Explicit retry after transient failures. Conflict requires separate
  /// user intervention and must not silently overwrite external changes.
  Future<void> retry() {
    if (_phase == SavePhase.conflict) {
      throw const DraftConflict();
    }
    return flush();
  }

  /// Attempt to flush on editor dismissal. Refuse to close if unsaved.
  /// Real OS process death may happen even after refusal; no guarantees.
  Future<bool> closeSafely() async {
    if (_closed) return true;
    await flush();
    if (!indicator.mayLeaveSafely) return false;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    return true;
  }

  /// Test-only teardown without saving. Never call as a production "Save".
  void abandonFictionalTestDraft() {
    _timer?.cancel();
    _timer = null;
    _closed = true;
  }
}
