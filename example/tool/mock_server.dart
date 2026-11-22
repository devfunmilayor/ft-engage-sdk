import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8788 : int.parse(args.first);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'Mock FT.Engage server on http://localhost:$port (accepts any pk_test_ key)',
  );
  final seen = <String>{};
  await for (final request in server) {
    final auth = request.headers.value('authorization') ?? '';
    request.response.headers.contentType = ContentType.json;
    if (!RegExp(r'^Bearer pk_test_').hasMatch(auth)) {
      request.response.statusCode = 401;
      request.response.write(jsonEncode({'error': 'invalid_key'}));
      await request.response.close();
      continue;
    }
    final body =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    if (request.uri.path == '/v1/register') {
      stdout.writeln('register ${jsonEncode(body)}');
      request.response.write(jsonEncode({'ok': true}));
    } else if (request.uri.path == '/v1/events') {
      final events = (body['events'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      var accepted = 0;
      for (final event in events) {
        if (seen.add(event['eventId'] as String)) accepted++;
        stdout.writeln(
          'event ${event['name']} ${jsonEncode(event['props'] ?? {})}',
        );
      }
      request.response.write(
        jsonEncode({
          'accepted': accepted,
          'duplicates': events.length - accepted,
          'rejected': [],
        }),
      );
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  }
}
