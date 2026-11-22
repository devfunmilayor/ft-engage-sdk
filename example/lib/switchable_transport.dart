import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class SwitchableTransport implements Transport {
  SwitchableTransport(this._inner);

  final Transport _inner;
  bool offline = false;

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) {
    if (offline) throw const TransportException('offline');
    return _inner.post(url, headers, body);
  }
}
