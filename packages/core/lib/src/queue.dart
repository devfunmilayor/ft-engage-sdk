import 'dart:convert';

import 'storage.dart';

class QueueBatch {
  const QueueBatch(this.events, this.rawCount);

  final List<Map<String, Object?>> events;
  final int rawCount;
}

class EventQueue {
  EventQueue(this._storage, this._maxSize);

  final EventStorage _storage;
  final int _maxSize;
  int _length = 0;
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  int get length => _length;

  Future<void> load() => _serial(() async {
    _length = await _storage.length();
  });

  Future<void> add(Map<String, Object?> event) => _serial(() async {
    await _storage.append(jsonEncode(event));
    _length += 1;
    final overflow = _length - _maxSize;
    if (overflow > 0) {
      await _storage.removeFirst(overflow);
      _length -= overflow;
    }
  });

  Future<QueueBatch> head(int count) => _serial(() async {
    final raw = await _storage.head(count);
    final events = <Map<String, Object?>>[];
    for (final json in raw) {
      try {
        events.add(Map<String, Object?>.from(jsonDecode(json) as Map));
      } on Object {
        continue;
      }
    }
    return QueueBatch(events, raw.length);
  });

  Future<void> removeFirst(int count) => _serial(() async {
    await _storage.removeFirst(count);
    _length = (_length - count).clamp(0, _length);
  });

  Future<void> clear() => _serial(() async {
    await _storage.clear();
    _length = 0;
  });
}
