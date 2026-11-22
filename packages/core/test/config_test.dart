import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

EngageConfig build(String key, String endpoint) =>
    EngageConfig(publicKey: key, endpoint: Uri.parse(endpoint));

void main() {
  test('a secret key is refused with a clear message', () {
    expect(
      () => build(
        ['sk', 'live', 'abcdefghijklmnopqrstuvwxyz012345'].join('_'),
        'https://api.example.com',
      ),
      throwsA(
        isA<EngageConfigException>().having(
          (e) => e.message,
          'message',
          contains('secret key'),
        ),
      ),
    );
  });

  test('keys that are not public keys are refused', () {
    expect(
      () => build('hello', 'https://api.example.com'),
      throwsA(isA<EngageConfigException>()),
    );
  });

  test('plain http is only allowed for localhost', () {
    expect(
      () => build(testKey, 'http://api.example.com'),
      throwsA(isA<EngageConfigException>()),
    );
    expect(build(testKey, 'http://localhost:8788').endpoint.port, 8788);
    expect(build(testKey, 'https://api.example.com').endpoint.scheme, 'https');
  });

  test('batch size is capped at 50', () {
    final config = EngageConfig(
      publicKey: testKey,
      endpoint: Uri.parse('https://a.example'),
      batchSize: 500,
    );
    expect(config.batchSize, 50);
  });
}
