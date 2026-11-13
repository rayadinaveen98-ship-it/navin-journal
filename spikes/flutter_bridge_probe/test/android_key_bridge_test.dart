import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(FlutterAndroidKeyProtector.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const alias = 'nj-v1-0123456789abcdef0123456789abcdef-g1';
  final dataKey = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final aad = Uint8List.fromList([1, 2, 3]);
  final wrapped = WrappedSecret(
    List<int>.filled(12, 4),
    List<int>.filled(32, 5),
    List<int>.filled(16, 6),
  );

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('provision forwards exact alias and supports null void response', () async {
    MethodCall? observed;
    messenger.setMockMethodCallHandler(channel, (call) async {
      observed = call;
      return null;
    });
    await FlutterAndroidKeyProtector(channel: channel).provision(alias);
    expect(observed!.method, 'provision');
    expect((observed!.arguments as Map)['alias'], alias);
  });

  test('wrap forwards binary data and accepts only typed lengths', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'wrap');
      final args = call.arguments as Map;
      expect(args['alias'], alias);
      expect(args['dek'], dataKey);
      expect(args['aad'], aad);
      return {
        'nonce': Uint8List.fromList(wrapped.nonce),
        'ciphertext': Uint8List.fromList(wrapped.ciphertext),
        'tag': Uint8List.fromList(wrapped.tag),
      };
    });
    final output = await FlutterAndroidKeyProtector(channel: channel)
        .wrap(alias, dataKey, aad);
    expect(output.nonce, wrapped.nonce);
    expect(output.ciphertext, wrapped.ciphertext);
    expect(output.tag, wrapped.tag);
  });

  test('unwrap forwards authenticated data and returns a fresh key copy',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'unwrap');
      final args = call.arguments as Map;
      expect(args['nonce'], Uint8List.fromList(wrapped.nonce));
      expect(args['tag'], Uint8List.fromList(wrapped.tag));
      expect(args['aad'], aad);
      return Uint8List.fromList(dataKey);
    });
    final output = await FlutterAndroidKeyProtector(channel: channel)
        .unwrap(alias, wrapped, aad);
    expect(output, dataKey);
    output[0] = 255;
    expect(dataKey[0], 0);
  });

  test('retire forwards exact alias with no auto-provision', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    await FlutterAndroidKeyProtector(channel: channel).retire(alias);
    expect(calls, ['retire']);
  });

  test('rejects invalid alias before reaching native channel', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel).provision('bad-alias'),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  test('rejects 16-byte database key before native call', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .wrap(alias, Uint8List(16), aad),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  test('rejects empty authenticated context before native call', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .wrap(alias, dataKey, Uint8List(0)),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  test('rejects malformed encrypted metadata before native call', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel).unwrap(
        alias,
        WrappedSecret([0], wrapped.ciphertext, wrapped.tag),
        aad,
      ),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  test('rejects native response missing authentication tag', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => {
          'nonce': Uint8List(12),
          'ciphertext': Uint8List(32),
        });
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel).wrap(alias, dataKey, aad),
      throwsA(isA<NativeKeyBridgeFailure>()),
    );
  });

  test('rejects native response with incorrect key size', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => Uint8List(16));
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .unwrap(alias, wrapped, aad),
      throwsA(isA<NativeKeyBridgeFailure>()),
    );
  });

  test('missing keystore alias returns fail-closed key error', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(
        code: 'KEY_STATE',
        message: 'Never return this native detail to private UI',
      ),
    );
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .unwrap(alias, wrapped, aad),
      throwsA(isA<MissingVaultKey>()),
    );
  });

  test('authentication error returns fail-closed key error', () async {
    messenger.setMockMethodCallHandler(
        channel, (call) async => throw PlatformException(code: 'AUTH_FAILED'));
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .unwrap(alias, wrapped, aad),
      throwsA(isA<MissingVaultKey>()),
    );
  });

  test('missing plugin does not fall back to software provider', () async {
    // With no native handler installed in the Flutter unit-test environment,
    // MethodChannel will produce MissingPluginException.
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      FlutterAndroidKeyProtector(channel: channel)
          .unwrap(alias, wrapped, aad),
      throwsA(isA<NativeKeyBridgeFailure>()),
    );
  });

  test('unexpected native operation error is sanitized', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(
        code: 'SOME_NATIVE_ERROR',
        message: 'Sensitive exception details must stay hidden',
      ),
    );
    try {
      await FlutterAndroidKeyProtector(channel: channel)
          .unwrap(alias, wrapped, aad);
      fail('Should fail');
    } on NativeKeyBridgeFailure catch (error) {
      expect(error.toString(), isNot(contains('Sensitive')));
    }
  });
}
