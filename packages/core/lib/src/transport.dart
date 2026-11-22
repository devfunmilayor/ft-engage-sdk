class TransportResponse {
  const TransportResponse(this.status, this.body);

  final int status;
  final String body;
}

class TransportException implements Exception {
  const TransportException(this.message);

  final String message;

  @override
  String toString() => 'TransportException: $message';
}

abstract interface class Transport {
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  );
}
