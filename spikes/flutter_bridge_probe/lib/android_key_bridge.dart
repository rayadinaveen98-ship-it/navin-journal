/// A2.4 TEST HARNESS — Flutter to AndroidKeyStore via a MethodChannel.
///
/// For fictional data only. Not a production keychain, secure vault, app
/// lock, recovery engine, or journal app. A 32-byte database key passes
/// across a Dart/Android platform channel; Dart/codec/native copies cannot
/// be proven wiped. No silent key generation happens during unwrap.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

class NativeKeyBridgeFailure implements Exception {
  final String code;
  const NativeKeyBridgeFailure(this.code);

  @override
  String toString() => 'NativeKeyBridgeFailure($code)';
}

/// Binds to the concrete AndroidKeyStore adapter in the stage-4 probe app.
///
/// The same interface is used by the A2.2 Linux fake-provider tests; this
/// adapter is never allowed to fall back to a software provider when native
/// key management is missing.
class FlutterAndroidKeyProtector implements DeviceKeyProtector {
  static const channelName = 'navin_journal/security_key_wrap_v1';
  static final RegExp _aliasPattern =
      RegExp(r'^nj-v1-[0-9a-f]{32}-g[1-9][0-9]*$');

  final MethodChannel _channel;
  FlutterAndroidKeyProtector({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  void _requireAlias(String alias) {
    if (!_aliasPattern.hasMatch(alias)) {
      throw ArgumentError.value(alias, 'alias', 'Unexpected key alias format');
    }
  }

  void _requireKey(Uint8List data) {
    if (data.length != 32) {
      throw ArgumentError('Expected exactly 32 bytes of data key');
    }
  }

  void _requireAad(Uint8List aad) {
    if (aad.isEmpty) {
      throw ArgumentError('Authenticated context is required');
    }
  }

  Future<T> _native<T>(String method, Map<String, Object> args) async {
    try {
      final result = await _channel.invokeMethod<T>(method, args);
      if (result == null) throw const NativeKeyBridgeFailure('EMPTY_RESPONSE');
      return result;
    } on MissingPluginException {
      throw const NativeKeyBridgeFailure('NATIVE_ADAPTER_UNAVAILABLE');
    } on PlatformException catch (e) {
      // Error details and native stack traces must not surface to private UI.
      switch (e.code) {
        case 'KEY_STATE':
        case 'AUTH_FAILED':
          throw MissingVaultKey('Device wrapping key unavailable or invalid');
        case 'INVALID_ARGUMENT':
          throw const NativeKeyBridgeFailure('NATIVE_REJECTED_INPUT');
        default:
          throw const NativeKeyBridgeFailure('NATIVE_OPERATION_FAILED');
      }
    }
  }

  @override
  Future<void> provision(String alias) async {
    _requireAlias(alias);
    // void-returning host method legitimately returns null.
    try {
      await _channel.invokeMethod<void>('provision', {'alias': alias});
    } on MissingPluginException {
      throw const NativeKeyBridgeFailure('NATIVE_ADAPTER_UNAVAILABLE');
    } on PlatformException catch (e) {
      if (e.code == 'KEY_STATE') {
        throw MissingVaultKey('Key alias is unavailable or already exists');
      }
      throw const NativeKeyBridgeFailure('PROVISION_FAILED');
    }
  }

  @override
  Future<WrappedSecret> wrap(
      String alias, Uint8List dataKey, Uint8List aad) async {
    _requireAlias(alias);
    _requireKey(dataKey);
    _requireAad(aad);
    final result = await _native<Map<dynamic, dynamic>>('wrap', {
      'alias': alias,
      'dek': dataKey,
      'aad': aad,
    });
    final nonce = result['nonce'];
    final cipher = result['ciphertext'];
    final tag = result['tag'];
    if (nonce is! Uint8List ||
        cipher is! Uint8List ||
        tag is! Uint8List ||
        nonce.length != 12 ||
        cipher.length != 32 ||
        tag.length != 16) {
      throw const NativeKeyBridgeFailure('MALFORMED_WRAPPED_DATA');
    }
    return WrappedSecret(nonce.toList(), cipher.toList(), tag.toList());
  }

  @override
  Future<Uint8List> unwrap(
      String alias, WrappedSecret wrapped, Uint8List aad) async {
    _requireAlias(alias);
    _requireAad(aad);
    if (wrapped.nonce.length != 12 ||
        wrapped.ciphertext.length != 32 ||
        wrapped.tag.length != 16) {
      throw ArgumentError('Unexpected wrapped-key payload sizes');
    }
    final result = await _native<Uint8List>('unwrap', {
      'alias': alias,
      'nonce': Uint8List.fromList(wrapped.nonce),
      'ciphertext': Uint8List.fromList(wrapped.ciphertext),
      'tag': Uint8List.fromList(wrapped.tag),
      'aad': aad,
    });
    if (result.length != 32) {
      throw const NativeKeyBridgeFailure('MALFORMED_UNWRAPPED_KEY');
    }
    // The returned key is a copy owned by the caller. See memory safety note.
    return Uint8List.fromList(result);
  }

  @override
  Future<void> retire(String alias) async {
    _requireAlias(alias);
    try {
      await _channel.invokeMethod<void>('retire', {'alias': alias});
    } on MissingPluginException {
      throw const NativeKeyBridgeFailure('NATIVE_ADAPTER_UNAVAILABLE');
    } on PlatformException catch (e) {
      if (e.code == 'KEY_STATE') {
        throw MissingVaultKey('Wrapping key already missing');
      }
      throw const NativeKeyBridgeFailure('RETIRE_FAILED');
    }
  }
}
