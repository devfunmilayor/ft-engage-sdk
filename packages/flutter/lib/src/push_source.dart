class PushState {
  const PushState({required this.status, this.token});

  final String status;
  final String? token;

  static const unknown = PushState(status: 'unknown');

  @override
  bool operator ==(Object other) =>
      other is PushState && other.status == status && other.token == token;

  @override
  int get hashCode => Object.hash(status, token);
}

abstract interface class PushSource {
  Future<PushState> read();
}

abstract interface class PushChanges {
  Stream<void> get changes;
}

abstract interface class PushPermission {
  Future<PushState> request();
}
