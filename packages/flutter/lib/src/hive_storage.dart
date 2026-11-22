import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'encryption_key.dart';

class HiveStorage implements EngageStorage {
  HiveStorage._(this._state, this._queue);

  static const stateBoxName = 'ft_engage_state';
  static const queueBoxName = 'ft_engage_queue';

  final Box<String> _state;
  final Box<String> _queue;

  static Future<HiveStorage> open({
    bool encrypt = true,
    EncryptionKeyProvider? keyProvider,
    String? path,
  }) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('ft_engage');
    }
    HiveCipher? cipher;
    if (encrypt) {
      cipher = HiveAesCipher(
        await (keyProvider ?? SecureStorageKeyProvider()).key(),
      );
    }
    return HiveStorage._(
      await _openBox(stateBoxName, cipher),
      await _openBox(queueBoxName, cipher),
    );
  }

  static Future<Box<String>> _openBox(String name, HiveCipher? cipher) async {
    try {
      return await Hive.openBox<String>(name, encryptionCipher: cipher);
    } on Object {
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name, encryptionCipher: cipher);
    }
  }

  Future<void> close() async {
    await _state.close();
    await _queue.close();
  }

  @override
  Future<String?> read(String key) async => _state.get(key);

  @override
  Future<void> write(String key, String value) => _state.put(key, value);

  @override
  Future<void> delete(String key) => _state.delete(key);

  @override
  Future<int> length() async => _queue.length;

  @override
  Future<void> append(String json) async {
    await _queue.add(json);
  }

  @override
  Future<List<String>> head(int count) async =>
      _queue.keys.take(count).map((key) => _queue.get(key)!).toList();

  @override
  Future<void> removeFirst(int count) =>
      _queue.deleteAll(_queue.keys.take(count).toList());

  @override
  Future<void> clear() async {
    await _queue.clear();
  }
}
