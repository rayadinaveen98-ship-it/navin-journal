/// APK 02 full-schema encrypted editor worker, FICTIONAL FIXTURES ONLY.
///
/// The Flutter UI isolate never touches SQLite or executes transactions.
/// One background isolate owns JournalVault, journal CRUD and journal-editor
/// commit ports. Existing validated debounce/IME/save-state behavior remains
/// in DraftAutosaveController on the Flutter side.
///
/// Android key initialization/unwrapping is OUTSIDE this module; callers must
/// supply an authenticated 32-byte TestVaultKey and independently protect it.
/// This experiment is not approved for real private diaries.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

import 'journal_core_draft_port.dart';

class JournalEditorWorkerUnavailable implements Exception {
  const JournalEditorWorkerUnavailable();
  @override
  String toString() => 'JournalEditorWorkerUnavailable';
}

/// A single-worker library read. Journals and selected pages are returned in
/// one isolate response instead of relying on two Flutter fake-async turns.
class EncryptedJournalShelf {
  final List<Map<String, Object?>> journals;
  final List<Map<String, Object?>> pages;
  const EncryptedJournalShelf(this.journals, this.pages);
}

class JournalEditorWorker implements DraftCommitPort {
  final Isolate _worker;
  final ReceivePort _responses;
  final SendPort _commands;
  final Map<int, Completer<Map<Object?, Object?>>> _pending = {};
  int _nextRequest = 0;
  bool _closed = false;

  JournalEditorWorker._(this._worker, this._responses, this._commands) {
    _responses.listen(_onMessage);
  }

  /// Create only an absent encrypted database; reopen only an existing one.
  /// Never silently regenerate keys, vaults, journals, or entry IDs.
  static Future<JournalEditorWorker> open(
    String path, {
    required TestVaultKey key,
    bool create = false,
  }) async {
    if (path.trim().isEmpty) throw ArgumentError('Vault path required');
    final hex = key.hex; // Existing TestVaultKey contract; not logged.
    final raw = Uint8List.fromList(List<int>.generate(32,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
    final transferred = TransferableTypedData.fromList([raw]);
    raw.fillRange(0, raw.length, 0);
    final bootstrap = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _editorStorageWorker,
        [bootstrap.sendPort, path, create, transferred],
        errorsAreFatal: true,
      );
      final ready = await bootstrap.first.timeout(const Duration(seconds: 20));
      if (ready is! SendPort) {
        throw const JournalEditorWorkerUnavailable();
      }
      final responses = ReceivePort();
      return JournalEditorWorker._(isolate, responses, ready);
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      throw const JournalEditorWorkerUnavailable();
    } finally {
      bootstrap.close();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! Map || raw['id'] is! int) return;
    final id = raw['id'] as int;
    final waiting = _pending.remove(id);
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete(Map<Object?, Object?>.from(raw));
    }
  }

  Future<Map<Object?, Object?>> _send(
    String action,
    Map<String, Object?> payload,
  ) async {
    if (_closed) throw const JournalEditorWorkerUnavailable();
    final id = ++_nextRequest;
    final reply = Completer<Map<Object?, Object?>>();
    _pending[id] = reply;
    _commands.send({
      'id': id,
      'reply': _responses.sendPort,
      'action': action,
      ...payload,
    });
    late final Map<Object?, Object?> result;
    try {
      result = await reply.future.timeout(const Duration(seconds: 20));
    } finally {
      _pending.remove(id);
    }
    if (result['ok'] == true) return result;
    if (result['code'] == 'conflict') throw const DraftConflict();
    throw const JournalEditorWorkerUnavailable();
  }

  Future<String> createJournal(String name) async {
    final r = await _send('create_journal', {'name': name});
    return r['journalId'] as String;
  }

  Future<List<Map<String, Object?>>> listJournals({
    bool includeTrash = false,
  }) async {
    final r = await _send('list_journals', {'includeTrash': includeTrash});
    return [
      for (final value in r['journals'] as List)
        Map<String, Object?>.from(value as Map),
    ];
  }

  /// Load the journal list and exactly one journal's pages together. All
  /// decrypted metadata remains ephemeral on the caller's UI isolate.
  Future<EncryptedJournalShelf> loadJournalShelf(String journalId) async {
    final r = await _send('load_journal_shelf', {'journalId': journalId});
    return EncryptedJournalShelf(
      [
        for (final value in r['journals'] as List)
          Map<String, Object?>.from(value as Map),
      ],
      [
        for (final value in r['entries'] as List)
          Map<String, Object?>.from(value as Map),
      ],
    );
  }

  Future<List<Map<String, Object?>>> listEntries({
    String? journalId,
    bool includeTrash = false,
  }) async {
    final r = await _send('list_entries', {
      'journalId': journalId,
      'includeTrash': includeTrash,
    });
    return [
      for (final value in r['entries'] as List)
        Map<String, Object?>.from(value as Map),
    ];
  }

  Future<Map<String, Object?>?> readEntry(String id) async {
    final r = await _send('read_entry', {'entryId': id});
    if (r['present'] != true) return null;
    return Map<String, Object?>.from(r['entry'] as Map);
  }

  Future<int> historyCount(String id) async {
    final r = await _send('history_count', {'entryId': id});
    return r['count'] as int;
  }

  /// Historical versions are queried inside the same encrypted worker; this
  /// is for scripted verification only, not an unencrypted revision cache.
  Future<List<Map<String, Object?>>> readRevisions(String entryId) async {
    final r = await _send('read_revisions', {'entryId': entryId});
    return [
      for (final value in r['revisions'] as List)
        Map<String, Object?>.from(value as Map),
    ];
  }

  Future<bool> integrityCheck() async {
    final r = await _send('integrity', {});
    return r['healthy'] == true;
  }

  /// Generates a portable, authenticated v2 archive while the encrypted
  /// JournalVault is owned by its background worker. The recovery key is
  /// independent of the Android Keystore and never persisted by this worker.
  ///
  /// Fictional-fixture engineering API only. The recipient MUST safeguard
  /// the returned encrypted bytes and the recovery key separately.
  Future<Uint8List> exportRecoveryArchive(RecoveryKey recoveryKey) async {
    final raw = recoveryKey.snapshot();
    try {
      final r = await _send('export_recovery_archive', {
        'recoveryKey': TransferableTypedData.fromList([raw]),
      });
      final archive = r['archive'];
      if (archive is! TransferableTypedData) {
        throw const JournalEditorWorkerUnavailable();
      }
      return archive.materialize().asUint8List();
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  /// The return type keeps editor state independent of platform specifics.
  /// This works only after journalId is created/opened in the same vault.
  Future<IsolateJournalEditorSession> startSession({
    required String journalId,
    String? existingEntryId,
    Duration debounce = const Duration(milliseconds: 400),
    void Function(SaveIndicator)? onIndicator,
  }) async {
    final logical = newEditorSessionId();
    final r = await _send('start_session', {
      'sessionId': logical,
      'journalId': journalId,
      'existingEntryId': existingEntryId,
    });
    final present = r['present'] == true;
    final initial = present
        ? DraftContent(
            title: r['title'] as String,
            body: r['body'] as String,
          )
        : DraftContent.blank;
    final version = present ? r['version'] as int : 0;
    final controller = DraftAutosaveController(
      entryId: logical,
      storage: this,
      initial: initial,
      committedVersion: version,
      debounce: debounce,
      onIndicator: onIndicator,
    );
    return IsolateJournalEditorSession._(this, logical, controller);
  }

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    final r = await _send('commit', {
      'sessionId': entryId,
      'expectedVersion': expectedVersion,
      'title': content.title,
      'body': content.body,
    });
    return CommitReceipt(entryId, r['version'] as int);
  }

  Future<String?> persistedIdFor(String sessionId) async {
    final r = await _send('persisted_id', {'sessionId': sessionId});
    return r['persistedId'] as String?;
  }

  Future<void> close() async {
    if (_closed) return;
    try {
      await _send('close', {});
    } finally {
      _closed = true;
      _worker.kill(priority: Isolate.immediate);
      _responses.close();
      for (final pending in _pending.values) {
        if (!pending.isCompleted) {
          pending.completeError(const JournalEditorWorkerUnavailable());
        }
      }
      _pending.clear();
    }
  }
}

class IsolateJournalEditorSession {
  final JournalEditorWorker worker;
  final String sessionId;
  final DraftAutosaveController controller;

  IsolateJournalEditorSession._(this.worker, this.sessionId, this.controller);

  SaveIndicator get indicator => controller.indicator;
  DraftContent get draft => controller.draft;
  Future<void> save() => controller.flush();
  Future<bool> closeSafely() => controller.closeSafely();

  /// Returned only after a committed real entry exists in encrypted storage.
  Future<String?> persistedEntryId() => worker.persistedIdFor(sessionId);
}

Future<void> _editorStorageWorker(List<Object> args) async {
  final ready = args[0] as SendPort;
  final path = args[1] as String;
  final create = args[2] as bool;
  final transfer = args[3] as TransferableTypedData;
  final raw = transfer.materialize().asUint8List();
  final key = TestVaultKey.fromBytes(raw);
  raw.fillRange(0, raw.length, 0);
  final incoming = ReceivePort();
  late final JournalVault vault;

  try {
    vault = JournalVault.open(path, key: key, create: create);
    key.destroy();
  } catch (_) {
    key.destroy();
    incoming.close();
    ready.send('OPEN_REFUSED');
    return;
  }

  final ports = <String, JournalCoreDraftPort>{};
  ready.send(incoming.sendPort);
  await for (final dynamic message in incoming) {
    if (message is! Map ||
        message['reply'] is! SendPort ||
        message['id'] is! int) {
      continue;
    }
    final reply = message['reply'] as SendPort;
    final id = message['id'] as int;
    try {
      switch (message['action']) {
        case 'create_journal':
          final journal = vault.createJournal(message['name'] as String);
          reply.send({'id': id, 'ok': true, 'journalId': journal});
        case 'list_journals':
          final journals = vault.listJournals(
            includeTrash: message['includeTrash'] == true,
          );
          reply.send({'id': id, 'ok': true, 'journals': journals});
        case 'load_journal_shelf':
          final journalId = message['journalId'] as String;
          final journals = vault.listJournals();
          if (!journals.any((j) =>
              j['id'] == journalId && j['deletedAtMs'] == null)) {
            throw const JournalUnavailable();
          }
          final pages = vault.listEntries(journalId: journalId);
          if (pages.any((entry) =>
              entry['journalId'] != journalId ||
              entry['deletedAtMs'] != null)) {
            throw const JournalUnavailable();
          }
          reply.send({
            'id': id, 'ok': true, 'journals': journals, 'entries': pages,
          });
        case 'list_entries':
          final entries = vault.listEntries(
            journalId: message['journalId'] as String?,
            includeTrash: message['includeTrash'] == true,
          );
          reply.send({'id': id, 'ok': true, 'entries': entries});
        case 'read_entry':
          final record = vault.readEntry(message['entryId'] as String);
          reply.send({
            'id': id, 'ok': true, 'present': record != null,
            if (record != null) 'entry': record,
          });
        case 'history_count':
          final records = vault.listRevisions(message['entryId'] as String);
          reply.send({'id': id, 'ok': true, 'count': records.length});
        case 'read_revisions':
          final records = vault.listRevisions(message['entryId'] as String);
          reply.send({'id': id, 'ok': true, 'revisions': records});
        case 'integrity':
          reply.send({'id': id, 'ok': true, 'healthy': vault.integrityCheck()});

        case 'export_recovery_archive':
          final transferred = message['recoveryKey'] as TransferableTypedData;
          final raw = transferred.materialize().asUint8List();
          RecoveryKey? recovery;
          try {
            // The raw recovery key travels only in the isolate message, not
            // through stdout, on-disk preferences or a plaintext export.
            recovery = RecoveryKey.parse(
              base64Url.encode(raw).replaceAll('=', ''),
            );
            final archive = await vault.exportEncrypted(recoveryKey: recovery);
            try {
              reply.send({
                'id': id, 'ok': true,
                'archive': TransferableTypedData.fromList([archive]),
              });
            } finally {
              archive.fillRange(0, archive.length, 0);
            }
          } finally {
            recovery?.destroy();
            raw.fillRange(0, raw.length, 0);
          }
        case 'start_session':
          final logical = message['sessionId'] as String;
          if (ports.containsKey(logical)) {
            throw const DraftConflict();
          }
          final port = JournalCoreDraftPort(
            vault: vault,
            journalId: message['journalId'] as String,
            sessionId: logical,
            existingEntryId: message['existingEntryId'] as String?,
          );
          final initial = port.readInitial();
          ports[logical] = port;
          reply.send({
            'id': id, 'ok': true, 'present': initial != null,
            if (initial != null) ...{
              'title': initial.content.title,
              'body': initial.content.body,
              'version': initial.version,
            },
          });
        case 'commit':
          final session = message['sessionId'] as String;
          final port = ports[session];
          if (port == null) throw const DraftConflict();
          final receipt = await port.commit(
            entryId: session,
            expectedVersion: message['expectedVersion'] as int,
            content: DraftContent(
              title: message['title'] as String,
              body: message['body'] as String,
            ),
          );
          reply.send({'id': id, 'ok': true, 'version': receipt.version});
        case 'persisted_id':
          final session = message['sessionId'] as String;
          final port = ports[session];
          if (port == null) throw const DraftConflict();
          reply.send({
            'id': id, 'ok': true,
            'persistedId': port.persistedEntryId,
          });
        case 'close':
          vault.close();
          incoming.close();
          reply.send({'id': id, 'ok': true});
          return;
        default:
          reply.send({'id': id, 'ok': false, 'code': 'bad_request'});
      }
    } on DraftConflict {
      reply.send({'id': id, 'ok': false, 'code': 'conflict'});
    } on JournalConflict {
      reply.send({'id': id, 'ok': false, 'code': 'conflict'});
    } catch (_) {
      // Never send text, SQL errors, native paths or key data as error details.
      reply.send({'id': id, 'ok': false, 'code': 'storage'});
    }
  }
  vault.close();
}
