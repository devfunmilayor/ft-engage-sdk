import 'dart:convert';

import 'storage.dart';

class EventQueue {
  EventQueue(this._store, this._maxSize);

  static const storageKey = 'ft_engage.queue';

  final KeyValueStore _store;
  final int _maxSize;
  List<Map<String, Object?>> _items = [];

  int get length => _items.length;

  Future<void> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<Object?>;
      _items = [
        for (final item in decoded) Map<String, Object?>.from(item! as Map),
      ];
    } on Object {
      _items = [];
    }
  }

  Future<void> add(Map<String, Object?> event) async {
    _items.add(event);
    if (_items.length > _maxSize) {
      _items = _items.sublist(_items.length - _maxSize);
    }
    await _save();
  }

  List<Map<String, Object?>> head(int count) => _items.take(count).toList();

  Future<void> removeFirst(int count) async {
    _items = _items.skip(count).toList();
    await _save();
  }

  Future<void> clear() async {
    _items = [];
    await _store.delete(storageKey);
  }

  Future<void> _save() => _store.write(storageKey, jsonEncode(_items));
}
