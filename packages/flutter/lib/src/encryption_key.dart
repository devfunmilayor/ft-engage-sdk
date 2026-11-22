import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class EncryptionKeyProvider {
  Future<List<int>> key();
}

class SecureStorageKeyProvider implements EncryptionKeyProvider {
  SecureStorageKeyProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _name = 'ft_engage.storage_key';

  final FlutterSecureStorage _storage;

  @override
  Future<List<int>> key() async {
    final existing = await _storage.read(key: _name);
    if (existing != null) return base64Decode(existing);
    final random = Random.secure();
    final fresh = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: _name, value: base64Encode(fresh));
    return fresh;
  }
}
