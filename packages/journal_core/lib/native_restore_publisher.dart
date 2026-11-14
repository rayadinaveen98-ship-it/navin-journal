/// Fictional-only Android/Linux atomic restore publication and fsync layer.
///
/// The encrypted journal must be independently verified before calling this.
/// Linux renameat2(RENAME_NOREPLACE) ensures concurrent destination creation
/// is never overwritten; no ordinary-rename fallback is allowed.
///
/// This is not a production power-loss or multi-device security guarantee.
library;

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef _RenameNative = Int32 Function(
  Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Uint32);
typedef _RenameDart = int Function(
  int, Pointer<Utf8>, int, Pointer<Utf8>, int);
typedef _OpenNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _OpenDart = int Function(Pointer<Utf8>, int);
typedef _FsyncNative = Int32 Function(Int32);
typedef _FsyncDart = int Function(int);
typedef _CloseNative = Int32 Function(Int32);
typedef _CloseDart = int Function(int);

class NativeRestorePublicationUnavailable implements Exception {
  const NativeRestorePublicationUnavailable();
  @override
  String toString() => 'NativeRestorePublicationUnavailable';
}

class NativeRestorePublisher {
  static const markerName = '.navin-restore-ready-v1';
  static const markerContents = 'NJR-RESTORE-PUBLISHED-V1\n';
  static const _atFdcwd = -100;
  static const _renameNoreplace = 1;
  static const _readOnly = 0;
  static const _directoryFlag = 0x10000;
  static const _noFollow = 0x20000;
  static const _closeOnExec = 0x80000;

  final _RenameDart _rename;
  final _OpenDart _open;
  final _FsyncDart _fsync;
  final _CloseDart _close;

  NativeRestorePublisher() : this._fromLibrary(_loadLibc());

  NativeRestorePublisher._fromLibrary(DynamicLibrary lib)
      : _rename = lib.lookupFunction<_RenameNative, _RenameDart>('renameat2'),
        _open = lib.lookupFunction<_OpenNative, _OpenDart>('open'),
        _fsync = lib.lookupFunction<_FsyncNative, _FsyncDart>('fsync'),
        _close = lib.lookupFunction<_CloseNative, _CloseDart>('close');

  static DynamicLibrary _loadLibc() {
    if (Platform.isAndroid) return DynamicLibrary.open('libc.so');
    if (Platform.isLinux) return DynamicLibrary.open('libc.so.6');
    throw const NativeRestorePublicationUnavailable();
  }

  /// A successful return establishes no-clobber rename and parent fsync.
  /// A failure AFTER the rename may leave a complete, visible target.
  /// Never auto-delete that target: reopen and verify it independently.
  Future<void> publish({
    required Directory staging,
    required Directory destination,
    void Function(String checkpoint)? injectFailure,
  }) async {
    final sourcePath = staging.absolute.path;
    final targetPath = destination.absolute.path;
    final parentPath = destination.parent.absolute.path;
    if (sourcePath == targetPath ||
        staging.parent.absolute.path != parentPath ||
        await FileSystemEntity.type(sourcePath, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(parentPath, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(targetPath, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw const NativeRestorePublicationUnavailable();
    }

    final entries = await staging.list(followLinks: false).toList();
    for (final item in entries) {
      // File-only staging directory. Reject links and nested directories.
      if (await FileSystemEntity.type(item.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const NativeRestorePublicationUnavailable();
      }
    }
    if (!await File(sourcePath + Platform.pathSeparator +
        'journal.sqlite3').exists()) {
      throw const NativeRestorePublicationUnavailable();
    }

    final marker = File(sourcePath + Platform.pathSeparator + markerName);
    if (await marker.exists()) {
      throw const NativeRestorePublicationUnavailable();
    }
    // Readiness marker is a commit-state flag, not a crypto authenticator.
    await marker.writeAsString(markerContents, flush: true);
    final synced = await staging.list(followLinks: false).toList();
    for (final item in synced) {
      if (await FileSystemEntity.type(item.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const NativeRestorePublicationUnavailable();
      }
      _sync(item.path);
    }
    _sync(sourcePath, directory: true);
    _sync(parentPath, directory: true);
    injectFailure?.call('after_durable_stage_before_noreplace');

    final from = sourcePath.toNativeUtf8();
    final to = targetPath.toNativeUtf8();
    try {
      if (_rename(_atFdcwd, from, _atFdcwd, to, _renameNoreplace) != 0) {
        throw const NativeRestorePublicationUnavailable();
      }
    } finally {
      calloc.free(from);
      calloc.free(to);
    }
    // The directory is now visible: a failed parent fsync is an ambiguous
    // commit that must NOT be cleaned up or silently retried.
    injectFailure?.call('after_atomic_noreplace_rename');
    _sync(parentPath, directory: true);
  }

  static Future<bool> isReady(Directory destination) async {
    final marker = File(
        destination.path + Platform.pathSeparator + markerName);
    final database = File(
        destination.path + Platform.pathSeparator + 'journal.sqlite3');
    if (!await marker.exists() || !await database.exists()) return false;
    try {
      return await marker.readAsString() == markerContents;
    } on FileSystemException {
      return false;
    }
  }

  void _sync(String path, {bool directory = false}) {
    final nativePath = path.toNativeUtf8();
    int fd = -1;
    try {
      fd = _open(nativePath,
          _readOnly | _noFollow | _closeOnExec |
          (directory ? _directoryFlag : 0));
      if (fd < 0 || _fsync(fd) != 0) {
        throw const NativeRestorePublicationUnavailable();
      }
    } finally {
      if (fd >= 0) _close(fd);
      calloc.free(nativePath);
    }
  }
}
