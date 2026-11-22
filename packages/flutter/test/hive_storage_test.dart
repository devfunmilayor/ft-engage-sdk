import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';
import 'package:hive_ce/hive.dart';

class FixedKey implements EncryptionKeyProvider {
  FixedKey(this.bytes);

  final List<int> bytes;

  @override
  Future<List<int>> key() async => bytes;
}

final keyA = List<int>.generate(32, (i) => i + 1);
final keyB = List<int>.generate(32, (i) => 200 - i);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ft_engage_hive_');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<HiveStorage> open({List<int>? key, bool encrypt = true}) =>
      HiveStorage.open(
        path: dir.path,
        encrypt: encrypt,
        keyProvider: FixedKey(key ?? keyA),
      );

  test('events keep their order and removal works from the front', () async {
    final storage = await open();
    for (var i = 0; i < 5; i++) {
      await storage.append('{"n":$i}');
    }
    expect(await storage.length(), 5);
    expect(await storage.head(3), ['{"n":0}', '{"n":1}', '{"n":2}']);
    await storage.removeFirst(2);
    expect(await storage.head(10), ['{"n":2}', '{"n":3}', '{"n":4}']);
    await storage.clear();
    expect(await storage.length(), 0);
    await storage.close();
  });

  test('state and queue survive closing and reopening', () async {
    final first = await open();
    await first.write('ft_engage.install_id', 'inst_00000001');
    await first.append('{"name":"app.opened"}');
    await first.close();

    final second = await open();
    expect(await second.read('ft_engage.install_id'), 'inst_00000001');
    expect(await second.head(1), ['{"name":"app.opened"}']);
    await second.delete('ft_engage.install_id');
    expect(await second.read('ft_engage.install_id'), isNull);
    await second.close();
  });

  test('encrypted files do not contain readable data', () async {
    final storage = await open();
    await storage.write('ft_engage.user_id', 'user_visible_marker');
    await storage.append('{"name":"signup.visible_marker"}');
    await storage.close();
    final bytes = <int>[];
    for (final file in dir.listSync().whereType<File>()) {
      bytes.addAll(file.readAsBytesSync());
    }
    final text = String.fromCharCodes(bytes);
    expect(text, isNot(contains('visible_marker')));
    expect(bytes, isNotEmpty);
  });

  test('without encryption the data is stored in readable form', () async {
    final storage = await open(encrypt: false);
    await storage.append('{"name":"signup.visible_marker"}');
    await storage.close();
    final bytes = <int>[];
    for (final file in dir.listSync().whereType<File>()) {
      bytes.addAll(file.readAsBytesSync());
    }
    expect(String.fromCharCodes(bytes), contains('visible_marker'));
  });

  test('a wrong key starts clean instead of crashing', () async {
    final first = await open(key: keyA);
    await first.append('{"n":1}');
    await first.close();
    final second = await open(key: keyB);
    expect(await second.length(), 0);
    await second.append('{"n":2}');
    expect(await second.head(1), ['{"n":2}']);
    await second.close();
  });

  test(
    'the whole client works on Hive: queue persists across a restart',
    () async {
      Future<EngageClient> client(HiveStorage storage) => EngageClient.create(
        config: EngageConfig(
          publicKey: 'pk_test_abcdefghijklmnopqrstuvwxyz012345',
          endpoint: Uri.parse('https://api.example.com'),
        ),
        transport: _Offline(),
        storage: storage,
      );
      final first = await client(await open());
      final id = first.installId;
      await first.track('app.opened');
      await first.track('signup.started');
      expect(first.pendingCount, 2);
      await Hive.close();

      final second = await client(await open());
      expect(second.installId, id);
      expect(second.pendingCount, 2);
    },
  );
}

class _Offline implements Transport {
  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) => throw const TransportException('offline');
}
