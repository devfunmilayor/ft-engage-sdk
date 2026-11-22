abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class EventStorage {
  Future<int> length();
  Future<void> append(String json);
  Future<List<String>> head(int count);
  Future<void> removeFirst(int count);
  Future<void> clear();
}

abstract interface class EngageStorage implements KeyValueStore, EventStorage {}

class MemoryStore implements EngageStorage {
  final Map<String, String> _values = {};
  final List<String> _events = [];

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<int> length() async => _events.length;

  @override
  Future<void> append(String json) async {
    _events.add(json);
  }

  @override
  Future<List<String>> head(int count) async => _events.take(count).toList();

  @override
  Future<void> removeFirst(int count) async {
    _events.removeRange(0, count.clamp(0, _events.length));
  }

  @override
  Future<void> clear() async {
    _events.clear();
  }
}
