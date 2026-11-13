/// A3.3 EXPERIMENT: serialized encrypted SQLite ownership in a background
/// Dart isolate. Fictional data only; not a production vault or Android app.
///
/// The UI isolate never opens a SQLite connection or performs disk transactions.
/// Raw 32-byte database keys do still cross isolate/process memory boundaries,
/// and this experiment has no platform key recovery or OS-kill guarantees.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';

import 'draft_autosave.dart';
import 'encrypted_draft_store.dart';

class StoredDraft {
  final DraftContent content;
  final int version;
  const StoredDraft(this.content, this.version);
}

class EncryptedIsolateStore implements DraftCommitPort {
  final ReceivePort _responses;
  final Isolate _worker;
  final SendPort _commands;
  final Map<int, Completer<Map<Object?, Object?>>> _waiting = {};
  int _requestId = 0;
  bool _closed = false;

  EncryptedIsolateStore._(this._responses, this._worker, this._commands) {
    _responses.listen(_receive);
  }

  /// Only an existing file is opened unless create is explicitly true.
  /// A wrong/missing key is reported as a generic storage failure. No fallback
  /// plaintext store is ever created. See A2 device security work separately.
  static Future<EncryptedIsolateStore> open(
    String filename, {
    required TestVaultKey key,
    bool create = false,
  }) async {
    if (filename.trim().isEmpty) throw ArgumentError('Filename required');
    // Convert the test key to transferable byte material. Do not print, log,
    // serialize to a file or treat best-effort array clearing as full wipe.
    final hex = key.hex;
    final bytes = Uint8List.fromList(List.generate(
      32, (i) => int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16),
    ));
    final transferred = TransferableTypedData.fromList([bytes]);
    bytes.fillRange(0, bytes.length, 0);

    final bootstrap = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _storageWorker,
        [bootstrap.sendPort, filename, create, transferred],
        errorsAreFatal: true,
      );
      final result = await bootstrap.first.timeout(const Duration(seconds: 15));
      if (result is! SendPort) {
        throw StateError('Encrypted worker refused to open test database');
      }
      // The bootstrap port was consumed by .first, so use a distinct reply
      // channel for requests; that channel is handed to the worker per call.
      final replies = ReceivePort();
      return EncryptedIsolateStore._(replies, isolate, result);
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      rethrow;
    } finally {
      bootstrap.close();
    }
  }

  void _receive(dynamic message) {
    if (message is! Map) return;
    final requestId = message['id'];
    if (requestId is! int) return;
    final pending = _waiting.remove(requestId);
    if (pending != null && !pending.isCompleted) {
      pending.complete(Map<Object?, Object?>.from(message));
    }
  }

  Future<Map<Object?, Object?>> _send(String action, Map<String, Object?> fields) async {
    if (_closed) throw StateError('Encrypted worker has been closed');
    final id = ++_requestId;
    final response = Completer<Map<Object?, Object?>>();
    _waiting[id] = response;
    _commands.send({
      'id': id,
      'reply': _responses.sendPort,
      'action': action,
      ...fields,
    });
    final result = await response.future.timeout(const Duration(seconds: 20),
        onTimeout: () {
      _waiting.remove(id);
      throw StateError('Encrypted worker operation timed out');
    });
    if (result['ok'] == true) return result;
    if (result['code'] == 'conflict') throw const DraftConflict();
    throw StateError('Encrypted storage operation failed');
  }

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    final r = await _send('commit', {
      'entryId': entryId,
      'version': expectedVersion,
      'title': content.title,
      'body': content.body,
    });
    return CommitReceipt(entryId, r['version'] as int);
  }

  Future<StoredDraft?> read(String entryId) async {
    final r = await _send('read', {'entryId': entryId});
    if (r['present'] != true) return null;
    return StoredDraft(
      DraftContent(title: r['title'] as String, body: r['body'] as String),
      r['version'] as int,
    );
  }

  Future<bool> integrityCheck() async {
    final r = await _send('integrity', {});
    return r['healthy'] == true;
  }

  Future<void> close() async {
    if (_closed) return;
    try {
      await _send('close', {});
    } finally {
      _closed = true;
      _responses.close();
      _worker.kill(priority: Isolate.immediate);
      for (final pending in _waiting.values) {
        if (!pending.isCompleted) {
          pending.completeError(StateError('Encrypted worker closed'));
        }
      }
      _waiting.clear();
    }
  }
}

void _storageWorker(List<Object> args) async {
  final bootstrap = args[0] as SendPort;
  final filename = args[1] as String;
  final create = args[2] as bool;
  final transfer = args[3] as TransferableTypedData;
  final input = transfer.materialize().asUint8List();
  final key = TestVaultKey.fromBytes(input);
  input.fillRange(0, input.length, 0);
  final incoming = ReceivePort();
  EncryptedDraftStore? db;
  try {
    db = EncryptedDraftStore.open(filename, key: key, create: create);
    key.destroy();
  } catch (_) {
    key.destroy();
    bootstrap.send('OPEN_FAILED');
    incoming.close();
    return;
  }
  bootstrap.send(incoming.sendPort);
  await for (final dynamic message in incoming) {
    if (message is! Map) continue;
    final reply = message['reply'];
    final id = message['id'];
    if (reply is! SendPort || id is! int) continue;
    try {
      switch (message['action']) {
        case 'commit':
          final receipt = await db.commit(
            entryId: message['entryId'] as String,
            expectedVersion: message['version'] as int,
            content: DraftContent(
              title: message['title'] as String,
              body: message['body'] as String,
            ),
          );
          reply.send({'id': id, 'ok': true, 'version': receipt.version});
        case 'read':
          final entryId = message['entryId'] as String;
          final content = db.read(entryId);
          final version = db.getVersion(entryId);
          reply.send({
            'id': id,
            'ok': true,
            'present': content != null,
            if (content != null) ...{
              'title': content.title,
              'body': content.body,
              'version': version,
            },
          });
        case 'integrity':
          reply.send({'id': id, 'ok': true, 'healthy': db.integrityCheck()});
        case 'close':
          db.close();
          reply.send({'id': id, 'ok': true});
          incoming.close();
          return;
        default:
          reply.send({'id': id, 'ok': false, 'code': 'bad_request'});
      }
    } on DraftConflict {
      reply.send({'id': id, 'ok': false, 'code': 'conflict'});
    } catch (_) {
      // Never leak SQL/key/draft/error details across the worker protocol.
      reply.send({'id': id, 'ok': false, 'code': 'storage'});
    }
  }
  db.close();
}
