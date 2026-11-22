import 'package:http/http.dart' as http;

import 'transport.dart';

class HttpTransport implements Transport {
  HttpTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    try {
      final response = await _client
          .post(url, headers: headers, body: body)
          .timeout(timeout);
      return TransportResponse(response.statusCode, response.body);
    } on Exception catch (error) {
      throw TransportException(error.runtimeType.toString());
    }
  }
}
