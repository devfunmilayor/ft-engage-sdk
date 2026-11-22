class EngageConfigException implements Exception {
  const EngageConfigException(this.message);

  final String message;

  @override
  String toString() => 'EngageConfigException: $message';
}

class InvalidEventException implements Exception {
  const InvalidEventException(this.message);

  final String message;

  @override
  String toString() => 'InvalidEventException: $message';
}
