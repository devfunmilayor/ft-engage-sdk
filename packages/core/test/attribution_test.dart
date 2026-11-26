import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

const hit =
    '{"ok":true,"attributed":true,"source":"meta","medium":"cpc","campaign":"spring","method":"referrer","deepLink":"/promo"}';

class Replying extends ScriptedTransport {
  Replying(this.statusFor, this.bodyFor);

  final int Function(Uri url) statusFor;
  final String Function(Uri url) bodyFor;

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    await super.post(url, headers, body);
    return TransportResponse(statusFor(url), bodyFor(url));
  }
}

void main() {
  test(
    'the referrer is reported once with the install id, and the answer is remembered',
    () async {
      final transport = Replying(
        (_) => 200,
        (u) => u.path == '/v1/attribution/install' ? hit : '{}',
      );
      final client = await makeClient(transport: transport);
      final first = await client.reportAttribution(
        referrer: 'ftclick=abc&utm_source=meta',
      );
      expect(
        [first?.attributed, first?.source, first?.deepLink, first?.method],
        [true, 'meta', '/promo', 'referrer'],
      );
      final call = transport.to('/v1/attribution/install').single;
      expect(call.json, {
        'installId': client.installId,
        'referrer': 'ftclick=abc&utm_source=meta',
      });
      final again = await client.reportAttribution(referrer: 'something=else');
      expect(again?.source, 'meta');
      expect(transport.to('/v1/attribution/install'), hasLength(1));
    },
  );

  test(
    'an Apple token is sent on its own, and an empty report sends nothing',
    () async {
      final transport = Replying(
        (_) => 200,
        (u) => u.path == '/v1/attribution/install'
            ? '{"ok":true,"attributed":false}'
            : '{}',
      );
      final client = await makeClient(transport: transport);
      expect(await client.reportAttribution(), isNull);
      expect(await client.reportAttribution(referrer: ''), isNull);
      final result = await client.reportAttribution(appleToken: 'token-1');
      expect(result?.attributed, false);
      expect(transport.to('/v1/attribution/install').single.json, {
        'installId': client.installId,
        'appleToken': 'token-1',
      });
      await client.reportAttribution(appleToken: 'token-1');
      expect(transport.to('/v1/attribution/install'), hasLength(2));
    },
  );

  test(
    'a server that has not seen the install yet means try again later, and a network failure is not an answer',
    () async {
      final transport = Replying(
        (u) => u.path == '/v1/attribution/install' ? 404 : 200,
        (_) => '{}',
      );
      final client = await makeClient(transport: transport);
      final wait = await client.reportAttribution(referrer: 'utm_source=x');
      expect([wait?.attributed, wait?.retry], [false, true]);
      final failing = ScriptedTransport()..fallbackStatus = 500;
      final other = await makeClient(transport: failing);
      expect(await other.reportAttribution(referrer: 'utm_source=x'), isNull);
      final offline = ScriptedTransport();
      final client3 = await makeClient(transport: offline);
      offline.script.add(const TransportException('offline'));
      expect(await client3.reportAttribution(referrer: 'utm_source=x'), isNull);
    },
  );

  test(
    'nothing is reported without consent, and opening a link tracks only the campaign tags',
    () async {
      final transport = ScriptedTransport();
      final denied = await makeClient(
        transport: transport,
        requireConsent: true,
      );
      expect(await denied.reportAttribution(referrer: 'utm_source=x'), isNull);
      expect(transport.to('/v1/attribution/install'), isEmpty);
      final client = await makeClient(transport: transport);
      await client.trackLinkOpened(
        Uri.parse(
          'https://go.acme.test/c/AbCd1234?utm_source=meta&utm_campaign=spring&email=a@b.co',
        ),
      );
      await client.flush(force: true);
      final event =
          (transport.to('/v1/events').single.json['events'] as List).single
              as Map;
      expect(event['name'], 'link.opened');
      expect(event['props'], {
        'host': 'go.acme.test',
        'utm_source': 'meta',
        'utm_campaign': 'spring',
      });
    },
  );

  test('forgetting the person clears the remembered attribution', () async {
    final store = MemoryStore();
    final transport = Replying(
      (_) => 200,
      (u) => u.path == '/v1/attribution/install' ? hit : '{}',
    );
    final client = await makeClient(transport: transport, store: store);
    await client.reportAttribution(referrer: 'utm_source=meta');
    expect(await store.read('ft_engage.attribution'), isNotNull);
    await client.forget();
    expect(await store.read('ft_engage.attribution'), isNull);
  });
}
