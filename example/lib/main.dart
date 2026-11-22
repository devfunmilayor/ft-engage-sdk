import 'package:flutter/material.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

import 'example_app.dart';
import 'switchable_transport.dart';

const _key = String.fromEnvironment(
  'ENGAGE_KEY',
  defaultValue: 'pk_test_exampleexampleexampleexample00',
);
const _endpoint = String.fromEnvironment(
  'ENGAGE_ENDPOINT',
  defaultValue: 'http://localhost:8788',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final transport = SwitchableTransport(HttpTransport());
  final engage = await FtEngage.init(
    publicKey: _key,
    endpoint: Uri.parse(_endpoint),
    transport: transport,
    flushInterval: const Duration(seconds: 5),
  );
  runApp(ExampleApp(engage: engage, transport: transport));
}
